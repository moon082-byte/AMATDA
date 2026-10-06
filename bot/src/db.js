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

/**
 * 알림 일정을 통째로 교체한다. 이미 보낸 알림은 다시 보내지 않도록 표시를 유지한다.
 * 무료 요금제의 요청당 쿼리 수 제한에 걸리지 않도록 목록 전체를 JSON 하나로 넣는다.
 */
export async function replaceReminders(env, code, items) {
  const { results } = await env.DB.prepare(
    'SELECT key FROM reminders WHERE code = ? AND sent = 1',
  ).bind(code).all();
  const sent = new Set(results.map((r) => r.key));
  const rows = items.map((i) => ({
    key: i.key,
    fire_at: i.fireAt,
    due_at: i.dueAt,
    text: i.text,
    buttons: i.buttons?.length ? JSON.stringify(i.buttons) : null,
    sent: sent.has(i.key) ? 1 : 0,
  }));
  await env.DB.batch([
    env.DB.prepare('DELETE FROM reminders WHERE code = ?').bind(code),
    env.DB.prepare(
      `INSERT INTO reminders (code, key, fire_at, due_at, text, buttons, sent)
       SELECT ?1, j.value ->> 'key', j.value ->> 'fire_at', j.value ->> 'due_at',
              j.value ->> 'text', j.value ->> 'buttons', j.value ->> 'sent'
       FROM json_each(?2) AS j`,
    ).bind(code, JSON.stringify(rows)),
  ]);
}

/** 보낸 알림들을 한 번에 '보냄'으로 표시한다 */
export async function markSent(env, rows) {
  if (!rows.length) return;
  await env.DB.prepare(
    `UPDATE reminders SET sent = 1 WHERE EXISTS (
       SELECT 1 FROM json_each(?1) AS j
       WHERE j.value ->> 'code' = reminders.code AND j.value ->> 'key' = reminders.key)`,
  ).bind(JSON.stringify(rows.map((r) => ({ code: r.code, key: r.key })))).run();
}
