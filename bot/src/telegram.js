// 텔레그램 처리: 웹훅 명령어, 웹훅 등록, 1분마다 알림 발송

import { ackReminder, codesForChat, markDelivered, pendingCount, takeState, unlinkCodes } from './db.js';
import { MESSAGES, STALE_MS, cleanupBefore, parseCommand } from './logic.js';
import { afterSend, nagKeyboard, nagText } from './nag.js';

export async function webhook(request, env) {
  if (request.headers.get('X-Telegram-Bot-Api-Secret-Token') !== (await webhookSecret(env))) {
    return new Response('forbidden', { status: 403 });
  }
  const update = await request.json();
  if (update.callback_query) {
    await onButton(env, update.callback_query);
    return new Response('ok');
  }
  const msg = update.message ?? update.channel_post;
  const cmd = parseCommand(msg?.text);
  if (!msg || !cmd) return new Response('ok');

  const chatId = msg.chat.id;
  const name = msg.chat.title ?? msg.from?.first_name ?? '';
  if (cmd.command === 'start') {
    // 로그인한 앱이 만든 연결 코드면 계정에 연결 (계정 연결은 code = user_id)
    const account = await takeState(env, cmd.arg, 'tg');
    if (account) {
      await env.DB.prepare(
        'INSERT OR REPLACE INTO links (code, chat_id, chat_name, created_at, user_id) VALUES (?, ?, ?, ?, ?)',
      ).bind(account.user_id, chatId, name, Date.now(), account.user_id).run();
      await tg(env, 'sendMessage', { chat_id: chatId, text: MESSAGES.welcome(name) });
    } else {
      await tg(env, 'sendMessage', { chat_id: chatId, text: MESSAGES.needCode });
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

/** 메시지 아래 [✅ 확인]을 누르면 끈질긴 알림을 끄고 버튼을 '확인함'으로 바꾼다 */
async function onButton(env, cq) {
  const ackId = /^ack:(.+)$/.exec(cq.data ?? '')?.[1];
  const ok = !!ackId && (await ackReminder(env, ackId, { chatId: cq.message?.chat?.id }));
  const text = ok ? '확인했어요. 다시 알리지 않을게요' : cq.data === 'done' ? '이미 확인했어요' : '지난 알림이에요';
  const answered = await tg(env, 'answerCallbackQuery', { callback_query_id: cq.id, text });
  if (!answered.ok) console.error('버튼 응답 실패', answered.status, answered.description);
  if (!ok || !cq.message) return;
  const inline_keyboard = (cq.message.reply_markup?.inline_keyboard ?? []).map((row) =>
    row.map((b) => (b.callback_data === cq.data ? { text: '✅ 확인함', callback_data: 'done' } : b)));
  const edited = await tg(env, 'editMessageReplyMarkup', {
    chat_id: cq.message.chat.id, message_id: cq.message.message_id, reply_markup: { inline_keyboard },
  });
  if (!edited.ok) console.error('버튼 바꾸기 실패', edited.status, edited.description);
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
    allowed_updates: ['message', 'channel_post', 'callback_query'],
  });
  await tg(env, 'setMyCommands', {
    commands: [
      { command: 'status', description: '연결 상태와 예정된 알림 수' },
      { command: 'stop', description: '알림 연결 끊기' },
    ],
  });
  // 배포 직후에는 옛 버전이 응답할 수 있으므로, 실제로 등록된 내용을 다시 확인해 보여준다
  const info = await tg(env, 'getWebhookInfo', {});
  const buttons = (info.result?.allowed_updates ?? []).includes('callback_query');
  const body = !hook.ok
    ? `❌ 등록 실패: ${hook.description}`
    : `✅ 텔레그램 웹훅 등록 완료\n버튼 누름 받기: ${buttons ? '켜짐' : '꺼짐 - 잠시 뒤 이 주소를 다시 열어 주세요'}`;
  return new Response(body, {
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

export async function tg(env, method, payload) {
  const res = await fetch(`https://api.telegram.org/bot${env.BOT_TOKEN}/${method}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  });
  return { status: res.status, ...(await res.json().catch(() => ({ ok: false }))) };
}

/** 무료 요금제의 요청당 외부 호출 제한(50)을 넘지 않도록 1분에 보내는 최대 건수 */
const SEND_LIMIT = 30;

/**
 * 시각이 된 알림을 보낸다. 끈질긴 알림을 켠 계정은 확인하지 않은 알림을 5분마다 최대 3번 더 보낸다.
 * (예전 앱 연결처럼 계정이 없는 연결은 끈질긴 알림을 쓰지 않는다)
 */
export async function sendDueReminders(env) {
  const now = Date.now();
  const { results } = await env.DB.prepare(
    `SELECT r.code, r.key, r.text, r.buttons, r.ack_id, r.sent, r.repeats, l.chat_id,
            COALESCE(u.nag_enabled, 0) AS nag
     FROM reminders r JOIN links l ON l.code = r.code LEFT JOIN users u ON u.id = l.user_id
     WHERE r.due_at >= ?1 AND (
       (r.sent = 0 AND r.fire_at <= ?2) OR
       (r.sent = 1 AND r.acked = 0 AND r.next_at <= ?2 AND COALESCE(u.nag_enabled, 0) = 1))
     ORDER BY CASE WHEN r.sent = 0 THEN r.fire_at ELSE r.next_at END LIMIT ${SEND_LIMIT}`,
  ).bind(now - STALE_MS, now).all();

  const done = [];
  const blocked = new Set();
  for (const row of results) {
    if (blocked.has(row.code)) continue;
    const nag = row.nag === 1 && !!row.ack_id;
    const message = { chat_id: row.chat_id, text: nagText(row.text, row.sent ? row.repeats + 2 : 1) };
    const ackId = nag ? row.ack_id : null;
    // [앱에서 보기]는 미니앱 버튼(개인 대화방만 가능)으로. 텔레그램이 거부하면 링크 버튼, 그래도 안 되면 글만 보낸다.
    const tries = [
      ...(row.chat_id > 0 ? [nagKeyboard(row.buttons, ackId, { webApp: true })] : []),
      nagKeyboard(row.buttons, ackId),
      undefined,
    ];
    let res;
    for (const keyboard of tries) {
      res = await tg(env, 'sendMessage', keyboard ? { ...message, reply_markup: keyboard } : message);
      if (res.status !== 400) break;
    }
    if (res.status === 403) {
      blocked.add(row.code); // 사용자가 봇을 차단함
    } else if (res.ok) {
      done.push(afterSend(row, nag, now));
    } else if (res.status === 400) {
      // 400(잘못된 요청)은 다시 보내도 실패하므로 보낸 것으로 처리하고 더 보내지 않는다
      done.push(afterSend(row, false, now));
    }
  }
  await markDelivered(env, done);
  await unlinkCodes(env, [...blocked]);
  await env.DB.prepare('DELETE FROM reminders WHERE due_at < ?').bind(cleanupBefore(now)).run();
}
