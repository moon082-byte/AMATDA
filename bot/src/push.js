// 휴대폰·PC 시스템 알림 (Web Push)
// - GET    /api/push/key         서버 공개키 (앱이 구독할 때 쓴다)
// - POST   /api/push/subscribe   이 기기의 구독 저장 {endpoint, keys: {p256dh, auth}}
// - DELETE /api/push/subscribe   이 기기의 구독 삭제 {endpoint}
// - 1분마다(cron) 시각이 된 알림을 그 계정의 모든 구독 기기로 보낸다 (텔레그램과 별도로 push_sent에 기록)

import { HttpError, readJson, validate } from './http.js';
import { recordReminders } from './inbox.js';
import { STALE_MS } from './logic.js';
import { fromBase64url, pushConfigured, sendWebPush } from './webpush.js';

/** 계정당 보관하는 구독(기기) 수. 넘으면 오래된 것부터 지운다 */
export const MAX_SUBSCRIPTIONS = 10;

/** 무료 요금제의 요청당 외부 호출 제한(50)을 텔레그램과 나눠 쓰도록 1분에 보내는 최대 푸시 수 */
export const PUSH_BUDGET = 15;

/** 앱이 보낸 구독 정보를 검사한다. 형식이 틀리면 예외 */
export function sanitizeSubscription(body) {
  const endpoint = typeof body?.endpoint === 'string' ? body.endpoint : '';
  if (!/^https:\/\/[^\s]+$/.test(endpoint) || endpoint.length > 1000) throw new Error('endpoint가 잘못됐어요');
  const p256dh = String(body?.keys?.p256dh ?? '');
  const auth = String(body?.keys?.auth ?? '');
  const size = (v) => {
    try {
      return /^[A-Za-z0-9_-]+=*$/.test(v) ? fromBase64url(v.replace(/=+$/, '')).length : -1;
    } catch {
      return -1;
    }
  };
  if (size(p256dh) !== 65 || size(auth) !== 16) throw new Error('구독 키가 잘못됐어요');
  return { endpoint, p256dh: p256dh.replace(/=+$/, ''), auth: auth.replace(/=+$/, '') };
}

/** [path]가 푸시 API면 [응답 내용, 상태 코드], 아니면 null */
export async function pushRoute(path, method, user, request, env) {
  if (path === '/api/push/key' && method === 'GET') {
    return [{ key: pushConfigured(env) ? env.VAPID_PUBLIC_KEY : null }];
  }
  if (path !== '/api/push/subscribe') return null;
  const raw = await readJson(request);
  if (method === 'POST') {
    if (!pushConfigured(env)) throw new HttpError(503, '서버에 푸시 설정(VAPID)이 아직 없어요');
    const sub = validate(() => sanitizeSubscription(raw));
    await env.DB.batch([
      env.DB.prepare(
        `INSERT INTO push_subscriptions (endpoint, user_id, p256dh, auth, created_at) VALUES (?1, ?2, ?3, ?4, ?5)
         ON CONFLICT (endpoint) DO UPDATE SET user_id = ?2, p256dh = ?3, auth = ?4, created_at = ?5`,
      ).bind(sub.endpoint, user.id, sub.p256dh, sub.auth, Date.now()),
      env.DB.prepare(
        `DELETE FROM push_subscriptions WHERE user_id = ?1 AND endpoint NOT IN
         (SELECT endpoint FROM push_subscriptions WHERE user_id = ?1 ORDER BY created_at DESC LIMIT ${MAX_SUBSCRIPTIONS})`,
      ).bind(user.id),
    ]);
    return [{ ok: true }];
  }
  if (method === 'DELETE') {
    await env.DB.prepare('DELETE FROM push_subscriptions WHERE endpoint = ? AND user_id = ?')
      .bind(String(raw?.endpoint ?? ''), user.id).run();
    return [{ ok: true }];
  }
  return null;
}

/**
 * 알림 일정 한 건을 푸시 내용으로 바꾼다.
 * 첫 줄 "[체크리스트 업무] 보고서" → 제목 "보고서", 나머지 줄(업무링크 제외) → 본문, [앱에서 보기] 주소 → 누르면 열 주소.
 */
export function pushMessage(row) {
  const [first = '', ...rest] = String(row.text).split('\n');
  let url = null;
  try {
    url = JSON.parse(row.buttons ?? '[]')[0]?.url ?? null;
  } catch {
    url = null;
  }
  return {
    title: `🔔 ${first.replace(/^\[[^\]]+\]\s*/, '') || '아맞다 알림'}`,
    body: rest.filter((line) => !line.startsWith('[업무링크]')).join('\n'),
    tag: row.key,
    url,
  };
}

/** 시각이 된 알림을 구독 기기로 보낸다. 만료된 구독(404·410)은 지운다 */
export async function sendDuePushes(env) {
  if (!pushConfigured(env)) return;
  const now = Date.now();
  const { results } = await env.DB.prepare(
    `SELECT r.code, r.key, r.text, r.buttons, r.due_at FROM reminders r
     WHERE r.push_sent = 0 AND r.fire_at <= ?2 AND r.due_at >= ?1
       AND EXISTS (SELECT 1 FROM push_subscriptions s WHERE s.user_id = r.code)
     ORDER BY r.fire_at LIMIT ${PUSH_BUDGET}`,
  ).bind(now - STALE_MS, now).all();
  if (!results.length) return;

  const codes = [...new Set(results.map((r) => r.code))];
  const { results: subs } = await env.DB.prepare(
    `SELECT endpoint, user_id, p256dh, auth FROM push_subscriptions
     WHERE user_id IN (${codes.map(() => '?').join(',')})`,
  ).bind(...codes).all();

  let budget = PUSH_BUDGET;
  const done = [];
  const expired = new Set();
  for (const row of results) {
    const targets = subs.filter((s) => s.user_id === row.code && !expired.has(s.endpoint));
    if (targets.length > budget) break; // 나머지는 다음 1분에 보낸다
    budget -= targets.length;
    // 마감이 지나도 12시간까지는 보관했다가 전달한다
    const ttl = Math.max(60, Math.floor((row.due_at + STALE_MS - now) / 1000));
    let ok = 0;
    let retry = false;
    for (const sub of targets) {
      const status = await sendWebPush(sub, pushMessage(row), env, Math.min(ttl, 24 * 60 * 60)).catch(() => 0);
      if (status >= 200 && status < 300) ok++;
      else if (status === 404 || status === 410) expired.add(sub.endpoint);
      else if (status === 0 || status === 429 || status >= 500) retry = true;
    }
    // 한 기기도 못 받았고 일시적인 오류면 다음 1분에 다시 보낸다.
    // 한 기기라도 받았으면 그 기기에 중복으로 가지 않도록 보낸 것으로 친다.
    if (ok > 0 || !retry) done.push({ code: row.code, key: row.key });
  }
  const statements = [...expired].map((e) => env.DB.prepare('DELETE FROM push_subscriptions WHERE endpoint = ?').bind(e));
  if (done.length) {
    statements.push(env.DB.prepare(
      `UPDATE reminders SET push_sent = 1 FROM json_each(?1) AS j
       WHERE j.value ->> 'code' = reminders.code AND j.value ->> 'key' = reminders.key`,
    ).bind(JSON.stringify(done)));
  }
  if (statements.length) await env.DB.batch(statements);
  await recordReminders(env, results, done);
}
