// 봇 서버 DB(D1) 처리

import { ACK_PATTERN, ackIdFor } from './nag.js';

export const getLink = (env, code) =>
  env.DB.prepare('SELECT chat_id, chat_name, user_id FROM links WHERE code = ?').bind(code).first();

export async function codesForChat(env, chatId) {
  const { results } = await env.DB.prepare('SELECT code FROM links WHERE chat_id = ?').bind(chatId).all();
  return results.map((r) => r.code);
}

export async function pendingCount(env, codes) {
  const marks = codes.map(() => '?').join(',');
  const row = await env.DB.prepare(
    `SELECT COUNT(*) AS n FROM reminders WHERE sent = 0 AND fire_at > ? AND code IN (${marks})`,
  ).bind(Date.now(), ...codes).first();
  return row?.n ?? 0;
}

export async function unlinkCodes(env, codes) {
  if (!codes.length) return;
  await env.DB.batch(codes.flatMap((code) => [
    env.DB.prepare('DELETE FROM reminders WHERE code = ?').bind(code),
    env.DB.prepare('DELETE FROM links WHERE code = ?').bind(code),
  ]));
}

/**
 * 알림 일정을 통째로 교체한다. 이미 보낸 알림은 다시 보내지 않도록 보냄·확인·다시 보낸 상태를 유지한다.
 * 무료 요금제의 요청당 쿼리 수 제한에 걸리지 않도록 목록 전체를 JSON 하나로 넣는다.
 */
export async function replaceReminders(env, code, items) {
  const { results } = await env.DB.prepare(
    'SELECT key, acked, repeats, next_at FROM reminders WHERE code = ? AND sent = 1',
  ).bind(code).all();
  const sent = new Map(results.map((r) => [r.key, r]));
  const ackIds = await Promise.all(items.map((i) => ackIdFor(env, code, i.key)));
  const rows = items.map((i, n) => ({
    key: i.key,
    fire_at: i.fireAt,
    due_at: i.dueAt,
    text: i.text,
    buttons: i.buttons?.length ? JSON.stringify(i.buttons) : null,
    ack_id: ackIds[n],
    sent: sent.has(i.key) ? 1 : 0,
    acked: sent.get(i.key)?.acked ?? 0,
    repeats: sent.get(i.key)?.repeats ?? 0,
    next_at: sent.get(i.key)?.next_at ?? null,
  }));
  await env.DB.batch([
    env.DB.prepare('DELETE FROM reminders WHERE code = ?').bind(code),
    env.DB.prepare(
      `INSERT INTO reminders (code, key, fire_at, due_at, text, buttons, ack_id, sent, acked, repeats, next_at)
       SELECT ?1, j.value ->> 'key', j.value ->> 'fire_at', j.value ->> 'due_at',
              j.value ->> 'text', j.value ->> 'buttons', j.value ->> 'ack_id', j.value ->> 'sent',
              j.value ->> 'acked', j.value ->> 'repeats', j.value ->> 'next_at'
       FROM json_each(?2) AS j`,
    ).bind(code, JSON.stringify(rows)),
  ]);
}

/** 보낸 알림들을 한 번에 '보냄'으로 표시하고, 다시 보낸 횟수·다음 시각을 저장한다 ([afterSend] 결과) */
export async function markDelivered(env, rows) {
  if (!rows.length) return;
  await env.DB.prepare(
    `UPDATE reminders SET sent = 1, repeats = j.value ->> 'repeats', next_at = j.value ->> 'next_at'
     FROM json_each(?1) AS j
     WHERE j.value ->> 'code' = reminders.code AND j.value ->> 'key' = reminders.key`,
  ).bind(JSON.stringify(rows)).run();
}

/**
 * 끈질긴 알림을 끈다. 텔레그램 버튼이면 그 대화방([chatId])에 연결된 알림만,
 * 앱이면 그 계정([code] = user_id)의 알림만 끌 수 있다. 끈 알림이 있으면 true.
 */
export async function ackReminder(env, ackId, { code = null, chatId = null }) {
  if (!ACK_PATTERN.test(ackId ?? '')) return false;
  const res = await env.DB.prepare(
    `UPDATE reminders SET acked = 1, next_at = NULL
     WHERE ack_id = ?1 AND code IN (SELECT code FROM links WHERE code = ?2 OR chat_id = ?3)`,
  ).bind(ackId, code, chatId).run();
  return (res.meta?.changes ?? 0) > 0;
}

/** 일회용 값 저장 (oauth_states) */
export async function putState(env, { state, kind, verifier = null, returnTo = null, userId = null, ttlMs }) {
  const now = Date.now();
  await env.DB.batch([
    env.DB.prepare('DELETE FROM oauth_states WHERE expires_at < ?').bind(now),
    env.DB.prepare(
      'INSERT INTO oauth_states (state, kind, verifier, return_to, user_id, expires_at) VALUES (?, ?, ?, ?, ?, ?)',
    ).bind(state, kind, verifier, returnTo, userId, now + ttlMs),
  ]);
}

/** 일회용 값을 꺼내고 지운다. 없거나 만료됐으면 null */
export async function takeState(env, state, kind) {
  if (!state) return null;
  const row = await env.DB.prepare(
    'DELETE FROM oauth_states WHERE state = ? AND kind = ? RETURNING verifier, return_to, user_id, expires_at',
  ).bind(state, kind).first();
  return row && row.expires_at > Date.now() ? row : null;
}
