// 봇 서버의 순수 로직 (Cloudflare 없이 테스트할 수 있도록 분리)

/** 앱이 만드는 연결 코드 형식: 영문·숫자·_- 16~64자 (텔레그램 start 파라미터 규칙) */
export const CODE_PATTERN = /^[A-Za-z0-9_-]{16,64}$/;

export const MAX_REMINDERS = 300;
export const MAX_TEXT = 1000;
export const MAX_BUTTONS = 6;
export const STALE_MS = 12 * 60 * 60 * 1000; // 마감이 12시간 넘게 지난 알림은 보내지 않는다

/** "/start abc", "/start@봇이름 abc" → { command: 'start', arg: 'abc' } */
export function parseCommand(text) {
  const m = /^\/([a-z]+)(?:@\w+)?(?:\s+(\S+))?/i.exec((text ?? '').trim());
  return m ? { command: m[1].toLowerCase(), arg: m[2] ?? '' } : null;
}

/**
 * 앱이 보낸 알림 목록을 검사해 저장할 형태로 바꾼다. 잘못된 항목은 버린다.
 * @returns {{key:string, fireAt:number, dueAt:number, text:string, buttons:{text:string,url:string}[]}[]}
 */
export function sanitizeReminders(body) {
  const list = Array.isArray(body?.reminders) ? body.reminders : null;
  if (!list) throw new Error('reminders 배열이 필요해요');
  if (list.length > MAX_REMINDERS) throw new Error(`알림은 최대 ${MAX_REMINDERS}개까지예요`);
  const seen = new Set();
  const result = [];
  for (const r of list) {
    const key = typeof r?.key === 'string' ? r.key.slice(0, 200) : '';
    const fireAt = Number(r?.fireAt);
    const dueAt = Number(r?.dueAt);
    const text = typeof r?.text === 'string' ? r.text.slice(0, MAX_TEXT) : '';
    if (!key || !text || !Number.isFinite(fireAt) || !Number.isFinite(dueAt)) continue;
    if (seen.has(key)) continue;
    seen.add(key);
    result.push({ key, fireAt, dueAt, text, buttons: sanitizeButtons(r.buttons) });
  }
  return result;
}

/** 메시지 아래 링크 버튼: http(s) 주소만, 최대 [MAX_BUTTONS]개. 잘못된 버튼은 버린다. */
export function sanitizeButtons(list) {
  if (!Array.isArray(list)) return [];
  const result = [];
  for (const b of list) {
    const text = typeof b?.text === 'string' ? b.text.trim().slice(0, 64) : '';
    const url = typeof b?.url === 'string' ? b.url.trim() : '';
    if (!text || url.length > 1000 || !/^https?:\/\/[^\s]+$/i.test(url)) continue;
    result.push({ text, url });
    if (result.length >= MAX_BUTTONS) break;
  }
  return result;
}

/** 저장된 버튼(JSON)을 텔레그램 인라인 키보드로 바꾼다 (한 줄에 버튼 하나). 없으면 undefined. */
export function inlineKeyboard(buttonsJson) {
  let buttons;
  try {
    buttons = sanitizeButtons(JSON.parse(buttonsJson ?? '[]'));
  } catch {
    return undefined;
  }
  return buttons.length ? { inline_keyboard: buttons.map((b) => [b]) } : undefined;
}

/** 오래돼서 지워도 되는 알림 기준 시각 */
export function cleanupBefore(now) {
  return now - 2 * 24 * 60 * 60 * 1000;
}

export const MESSAGES = {
  welcome: (name) =>
    `✅ ${name ? `${name}님, ` : ''}아맞다와 연결됐어요!\n\n` +
    '앱에서 설정한 리마인드 시각이 되면 이 대화방으로 알려드릴게요.\n' +
    '앱을 닫아 둬도 알림이 와요.\n\n' +
    '연결을 끊으려면 /stop 을 보내 주세요.',
  needCode:
    '👋 아맞다 알림봇이에요.\n\n' +
    '앱의 설정 → "텔레그램 알림" → "텔레그램 연결"을 누르면 여기로 돌아와 자동으로 연결돼요.',
  stopped: '🔕 연결을 끊었어요. 더 이상 알림을 보내지 않아요.\n다시 받으려면 앱에서 "텔레그램 연결"을 눌러 주세요.',
  notLinked: '연결된 앱이 없어요. 앱의 설정에서 "텔레그램 연결"을 눌러 주세요.',
  status: (count) => `🔔 연결돼 있어요. 예정된 알림 ${count}개`,
  help:
    '사용할 수 있는 명령어\n' +
    '/status - 연결 상태와 예정된 알림 수\n' +
    '/stop - 연결 끊기',
};
