// 로그인한 계정의 텔레그램 API: 연결, 끈질긴 알림 설정, 알림 일정 올리기·끄기

import { randomToken } from './crypto.js';
import { ackReminder, getLink, putState, replaceReminders, unlinkCodes } from './db.js';
import { HttpError, readJson, validate } from './http.js';
import { sanitizeReminders, sanitizeRoomUrl } from './logic.js';

const TG_CODE_TTL = 30 * 60 * 1000;

/** [path]가 텔레그램 API면 [응답 내용, 상태 코드], 아니면 null */
export async function telegramRoute(path, method, user, request, env) {
  if (path === '/api/telegram/code' && method === 'POST') {
    const code = randomToken(24);
    await putState(env, { state: code, kind: 'tg', userId: user.id, ttlMs: TG_CODE_TTL });
    return [{ code }];
  }
  if (path === '/api/telegram' && method === 'GET') {
    const link = await getLink(env, user.id);
    const me = await env.DB.prepare('SELECT tg_room_url, nag_enabled FROM users WHERE id = ?').bind(user.id).first();
    return [{ linked: !!link, name: link?.chat_name ?? null, nag: me?.nag_enabled !== 0, roomUrl: me?.tg_room_url ?? '' }];
  }
  if (path === '/api/telegram' && method === 'DELETE') {
    await unlinkCodes(env, [user.id]);
    return [{ linked: false }];
  }
  if (path === '/api/telegram/nag' && method === 'PUT') {
    const raw = await readJson(request);
    if (typeof raw?.enabled !== 'boolean') throw new HttpError(400, 'enabled(true/false)가 필요해요');
    await env.DB.prepare('UPDATE users SET nag_enabled = ? WHERE id = ?').bind(raw.enabled ? 1 : 0, user.id).run();
    return [{ nag: raw.enabled }];
  }
  if (path === '/api/telegram/room' && method === 'PUT') {
    // 예전 버전 호환용 (지금 앱은 쓰지 않음)
    const raw = await readJson(request);
    const url = validate(() => sanitizeRoomUrl(raw?.url));
    await env.DB.prepare('UPDATE users SET tg_room_url = ? WHERE id = ?').bind(url || null, user.id).run();
    return [{ roomUrl: url }];
  }
  if (path === '/api/reminders' && method === 'PUT') {
    if (!(await getLink(env, user.id))) return [{ linked: false }, 404];
    const raw = await readJson(request);
    const items = validate(() => sanitizeReminders(raw));
    await replaceReminders(env, user.id, items);
    return [{ ok: true, count: items.length }];
  }
  if (path === '/api/reminders/ack' && method === 'POST') {
    // 텔레그램 [앱에서 보기]로 앱을 열면 그 알림의 끈질긴 알림을 끈다
    const raw = await readJson(request);
    return [{ ok: await ackReminder(env, raw?.ack, { code: user.id }) }];
  }
  return null;
}
