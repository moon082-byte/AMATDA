// 봇 서버 DB(D1) 처리

export const getLink = (env, code) =>
  env.DB.prepare('SELECT chat_id, chat_name FROM links WHERE code = ?').bind(code).first();

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

/** 알림 일정을 통째로 교체한다. 이미 보낸 알림은 다시 보내지 않도록 표시를 유지한다. */
export async function replaceReminders(env, code, items) {
  const { results } = await env.DB.prepare(
    'SELECT key FROM reminders WHERE code = ? AND sent = 1',
  ).bind(code).all();
  const sent = new Set(results.map((r) => r.key));
  await env.DB.batch([
    env.DB.prepare('DELETE FROM reminders WHERE code = ?').bind(code),
    ...items.map((i) => env.DB.prepare(
      'INSERT INTO reminders (code, key, fire_at, due_at, text, sent) VALUES (?, ?, ?, ?, ?, ?)',
    ).bind(code, i.key, i.fireAt, i.dueAt, i.text, sent.has(i.key) ? 1 : 0)),
  ]);
}
