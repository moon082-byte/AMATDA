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

/** 설정의 텔레그램 업무방 링크: http(s) 주소만, 비우면 ''. 잘못된 주소면 예외. */
export function sanitizeRoomUrl(value) {
  const url = typeof value === 'string' ? value.trim() : '';
  if (!url) return '';
  if (url.length > 500 || !/^https?:\/\/[^\s]+$/i.test(url)) throw new Error('http(s)로 시작하는 주소를 넣어 주세요');
  return url;
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

// ---- 계정·동기화 ----

/** 동기화하는 사용자 데이터 표 (DB 표 이름과 같다) */
export const SYNC_TABLES = ['rooms', 'tasks', 'sub_tasks', 'notes', 'routines'];
export const MAX_SYNC_ROWS = 500; // 한 번에 올릴 수 있는 변경 수
export const MAX_PULL_ROWS = 1000; // 한 번에 내려주는 변경 수
export const MAX_DATA = 20000; // 항목 하나의 내용(JSON) 최대 길이
export const SESSION_IDLE_MS = 60 * 24 * 60 * 60 * 1000; // 60일 동안 안 쓰면 로그인 만료
const ID_PATTERN = /^[A-Za-z0-9_.:-]{1,100}$/;

/**
 * 앱이 올린 변경 목록을 검사한다. 형식이 틀리면 예외, 잘못된 항목은 버린다.
 * @returns {{since:number, changes:Record<string, {id:string, parentId:string|null, position:number, data:string, deleted:number}[]>, total:number}}
 */
export function sanitizeSyncChanges(body) {
  const since = Number(body?.since ?? 0);
  if (!Number.isInteger(since) || since < 0) throw new Error('since가 잘못됐어요');
  const changes = {};
  let total = 0;
  for (const table of SYNC_TABLES) {
    const list = body?.changes?.[table] ?? [];
    if (!Array.isArray(list)) throw new Error(`${table}는 배열이어야 해요`);
    const seen = new Set();
    changes[table] = [];
    for (const r of list) {
      const id = typeof r?.id === 'string' ? r.id : '';
      if (!ID_PATTERN.test(id) || seen.has(id)) continue;
      const parentId = typeof r.parentId === 'string' && ID_PATTERN.test(r.parentId) ? r.parentId : null;
      const data = typeof r.data === 'string' ? r.data : JSON.stringify(r.data ?? {});
      if (data.length > MAX_DATA) continue;
      seen.add(id);
      changes[table].push({
        id,
        parentId,
        position: Number.isInteger(r.position) ? r.position : 0,
        data,
        deleted: r.deleted ? 1 : 0,
      });
    }
    total += changes[table].length;
  }
  if (total > MAX_SYNC_ROWS) throw new Error(`변경은 한 번에 최대 ${MAX_SYNC_ROWS}개까지예요`);
  return { since, changes, total };
}

/** "a@x.com, B@y.com" → Set('a@x.com', 'b@y.com') */
export function parseEmails(value) {
  return new Set((value ?? '').split(',').map((s) => s.trim().toLowerCase()).filter(Boolean));
}

/** 로그인 후 돌아갈 앱 주소. 허용된 곳(앱 주소·localhost)이 아니면 null. 검색어·# 부분은 뺀다. */
export function safeReturnTo(value, allowedOrigins) {
  let url;
  try {
    url = new URL(value);
  } catch {
    return null;
  }
  const allowed = (allowedOrigins ?? '').split(',').map((s) => s.trim()).filter(Boolean);
  const local = /^http:\/\/localhost(:\d+)?$/.test(url.origin);
  if (!allowed.includes(url.origin) && !local) return null;
  return `${url.origin}${url.pathname}`;
}

/** 구글 ID 토큰(JWT)의 내용 부분을 읽는다 (구글 토큰 주소에서 직접 받은 토큰이라 서명 확인은 생략) */
export function decodeJwtPayload(token) {
  const part = String(token ?? '').split('.')[1];
  if (!part) throw new Error('ID 토큰 형식이 아니에요');
  const base64 = part.replace(/-/g, '+').replace(/_/g, '/');
  const bytes = Uint8Array.from(atob(base64), (c) => c.charCodeAt(0));
  return JSON.parse(new TextDecoder().decode(bytes));
}

/** ID 토큰 내용 검사. 문제가 있으면 이유, 괜찮으면 null */
export function checkIdClaims(claims, clientId, now) {
  if (claims.aud !== clientId) return '다른 앱용 토큰이에요';
  if (!['accounts.google.com', 'https://accounts.google.com'].includes(claims.iss)) return '구글 토큰이 아니에요';
  if (!claims.sub || !claims.email) return '계정 정보가 없어요';
  if (claims.email_verified !== true && claims.email_verified !== 'true') return '이메일 인증이 안 된 계정이에요';
  if (Number(claims.exp) * 1000 < now) return '만료된 토큰이에요';
  return null;
}

// ---- 2차 비밀번호(PIN) ----

export const PIN_PATTERN = /^\d{4}$/;
export const PIN_MAX_TRIES = 5; // 연속으로 이만큼 틀리면 잠근다
export const PIN_RESET_TTL = 10 * 60 * 1000; // 재설정 코드 유효시간
export const PIN_RESET_MAX_TRIES = 5; // 재설정 코드를 이만큼 틀리면 코드를 버린다
export const FRESH_LOGIN_MS = 10 * 60 * 1000; // 구글로 막 로그인한 세션은 코드 없이 PIN을 다시 정할 수 있다

/** 몇 번째 잠금인지에 따른 잠금 시간: 처음 1분, 그 뒤로는 30분 */
export function pinLockDuration(level) {
  return level === 0 ? 60 * 1000 : 30 * 60 * 1000;
}

/**
 * PIN 입력 결과에 따른 다음 상태. 맞으면 횟수·잠금 단계를 처음으로 돌린다.
 * @param {{failed:number, lockedUntil:number, level:number}} state
 */
export function nextPinState(state, ok, now) {
  if (ok) return { failed: 0, lockedUntil: 0, level: 0 };
  const failed = state.failed + 1;
  if (failed < PIN_MAX_TRIES) return { ...state, failed };
  return { failed: 0, lockedUntil: now + pinLockDuration(state.level), level: state.level + 1 };
}
