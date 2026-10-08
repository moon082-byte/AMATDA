// 끈질긴 알림: [✅ 확인]을 누르거나 앱에서 [앱에서 보기]로 열 때까지 5분마다 최대 3번 더 보낸다

import { hmacHex } from './crypto.js';
import { sanitizeButtons } from './logic.js';

export const NAG_INTERVAL_MS = 5 * 60 * 1000;
export const NAG_MAX_REPEATS = 3;
export const ACK_PATTERN = /^[0-9a-f]{24}$/;

/** 알림마다 고정된 확인값. 서버 비밀값으로 만들어 남이 짐작해 끌 수 없다. */
export async function ackIdFor(env, code, key) {
  return (await hmacHex(`amatda-ack:${env.BOT_TOKEN}`, `${code}\n${key}`)).slice(0, 24);
}

/** 몇 번째로 보내는지(1부터). 다시 보내는 것이면 맨 위에 표시한다. */
export function nagText(text, nth) {
  return nth > 1 ? `🔁 다시 알림 (${nth}/${NAG_MAX_REPEATS + 1})\n${text}` : text;
}

/**
 * 메시지 아래 버튼 (한 줄). 끈질긴 알림이면 [✅ 확인]을 앞에 두고,
 * [앱에서 보기] 주소에 확인값을 붙여 앱에서 열면 반복이 멈추게 한다. 버튼이 없으면 undefined.
 */
export function nagKeyboard(buttonsJson, ackId) {
  let buttons;
  try {
    buttons = sanitizeButtons(JSON.parse(buttonsJson ?? '[]'));
  } catch {
    buttons = [];
  }
  if (ackId) {
    buttons = buttons.map((b) => (b.url.includes('?open=') ? { ...b, url: `${b.url}&ack=${ackId}` } : b));
  }
  const row = [...(ackId ? [{ text: '✅ 확인', callback_data: `ack:${ackId}` }] : []), ...buttons];
  return row.length ? { inline_keyboard: [row] } : undefined;
}

/** 보낸 뒤 저장할 상태: 다시 보낸 횟수와 다음에 다시 보낼 시각(더 보내지 않으면 null) */
export function afterSend(row, nag, now) {
  const repeats = row.sent ? row.repeats + 1 : 0;
  const more = nag && repeats < NAG_MAX_REPEATS;
  return { code: row.code, key: row.key, repeats, next_at: more ? now + NAG_INTERVAL_MS : null };
}
