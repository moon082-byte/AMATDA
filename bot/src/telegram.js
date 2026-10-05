// 텔레그램 처리: 웹훅 명령어, 웹훅 등록, 1분마다 알림 발송

import { codesForChat, pendingCount, unlinkCodes } from './db.js';
import { CODE_PATTERN, MESSAGES, STALE_MS, cleanupBefore, parseCommand } from './logic.js';

export async function webhook(request, env) {
  if (request.headers.get('X-Telegram-Bot-Api-Secret-Token') !== (await webhookSecret(env))) {
    return new Response('forbidden', { status: 403 });
  }
  const update = await request.json();
  const msg = update.message ?? update.channel_post;
  const cmd = parseCommand(msg?.text);
  if (!msg || !cmd) return new Response('ok');

  const chatId = msg.chat.id;
  const name = msg.chat.title ?? msg.from?.first_name ?? '';
  if (cmd.command === 'start') {
    if (!CODE_PATTERN.test(cmd.arg)) {
      await tg(env, 'sendMessage', { chat_id: chatId, text: MESSAGES.needCode });
    } else {
      await env.DB.prepare(
        'INSERT OR REPLACE INTO links (code, chat_id, chat_name, created_at) VALUES (?, ?, ?, ?)',
      ).bind(cmd.arg, chatId, name, Date.now()).run();
      await tg(env, 'sendMessage', { chat_id: chatId, text: MESSAGES.welcome(name) });
    }
  } else if (cmd.command === 'stop') {
    const codes = await codesForChat(env, chatId);
    await unlinkCodes(env, codes);
    await tg(env, 'sendMessage', { chat_id: chatId, text: codes.length ? MESSAGES.stopped : MESSAGES.notLinked });
  } else if (cmd.command === 'status') {
    const codes = await codesForChat(env, chatId);
    const text = codes.length ? MESSAGES.status(await pendingCount(env, codes)) : MESSAGES.notLinked;
    await tg(env, 'sendMessage', { chat_id: chatId, text });
  } else {
    await tg(env, 'sendMessage', { chat_id: chatId, text: MESSAGES.help });
  }
  return new Response('ok');
}

/** 봇 아이디·이름 (공개 정보). 앱 설정에 넣을 봇 아이디를 확인할 때 쓴다. */
export async function botInfo(env) {
  const me = await tg(env, 'getMe', {});
  return me.ok ? { username: me.result.username, name: me.result.first_name } : { error: me.description };
}

export async function setup(url, env) {
  const hook = await tg(env, 'setWebhook', {
    url: `${url.origin}/telegram/webhook`,
    secret_token: await webhookSecret(env),
    allowed_updates: ['message', 'channel_post'],
  });
  await tg(env, 'setMyCommands', {
    commands: [
      { command: 'status', description: '연결 상태와 예정된 알림 수' },
      { command: 'stop', description: '알림 연결 끊기' },
    ],
  });
  return new Response(hook.ok ? '✅ 텔레그램 웹훅 등록 완료' : `❌ 등록 실패: ${hook.description}`, {
    status: hook.ok ? 200 : 500,
    headers: { 'Content-Type': 'text/plain; charset=utf-8' },
  });
}

/** 텔레그램이 웹훅 요청에 붙여 보낼 비밀값 (봇 토큰에서 만들어 따로 관리할 필요가 없다) */
export async function webhookSecret(env) {
  const data = new TextEncoder().encode(`amatda-webhook:${env.BOT_TOKEN}`);
  const hash = new Uint8Array(await crypto.subtle.digest('SHA-256', data));
  return [...hash].map((b) => b.toString(16).padStart(2, '0')).join('').slice(0, 48);
}

async function tg(env, method, payload) {
  const res = await fetch(`https://api.telegram.org/bot${env.BOT_TOKEN}/${method}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return { status: res.status, ...(await res.json().catch(() => ({ ok: false }))) };
}

export async function sendDueReminders(env) {
  const now = Date.now();
  const { results } = await env.DB.prepare(
    `SELECT r.code, r.key, r.text, l.chat_id FROM reminders r
     JOIN links l ON l.code = r.code
     WHERE r.sent = 0 AND r.fire_at <= ? AND r.due_at >= ?
     ORDER BY r.fire_at LIMIT 100`,
  ).bind(now, now - STALE_MS).all();

  for (const row of results) {
    const res = await tg(env, 'sendMessage', { chat_id: row.chat_id, text: row.text });
    if (res.status === 403) {
      await unlinkCodes(env, [row.code]); // 사용자가 봇을 차단함
    } else if (res.ok || res.status === 400) {
      // 400(잘못된 요청)은 다시 보내도 실패하므로 보낸 것으로 처리한다
      await env.DB.prepare('UPDATE reminders SET sent = 1 WHERE code = ? AND key = ?')
        .bind(row.code, row.key).run();
    }
  }
  await env.DB.prepare('DELETE FROM reminders WHERE due_at < ?').bind(cleanupBefore(now)).run();
}
