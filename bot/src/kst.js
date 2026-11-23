// 한국 시간(UTC+9) 날짜 계산.
// 서버는 사용자 시간대를 모르므로 텔레그램 봇의 일정 조회·추가는 한국 시간 기준이다.

export const KST = 9 * 60 * 60 * 1000;
export const DAY = 24 * 60 * 60 * 1000;
export const WEEKDAYS = ['월', '화', '수', '목', '금', '토', '일'];

const pad = (n) => String(n).padStart(2, '0');

/** epoch ms → 한국 시간 { y, m(1~12), d, h, min, wd(1=월 ~ 7=일) } */
export function kst(ms) {
  const t = new Date(ms + KST);
  return {
    y: t.getUTCFullYear(), m: t.getUTCMonth() + 1, d: t.getUTCDate(),
    h: t.getUTCHours(), min: t.getUTCMinutes(), wd: ((t.getUTCDay() + 6) % 7) + 1,
  };
}

/** 한국 시간 → epoch ms (일·월이 넘치면 알아서 다음 달·해로 넘어간다) */
export const kstMs = (y, m, d, h = 0, min = 0) => Date.UTC(y, m - 1, d, h, min) - KST;

/** 그날 한국 시간 0시 */
export function startOfDay(ms) {
  const p = kst(ms);
  return kstMs(p.y, p.m, p.d);
}

/** 시간 없이 날짜만 정한 마감인지 (앱은 그날 00:00으로 저장한다) */
export const isDateOnly = (ms) => {
  const p = kst(ms);
  return p.h === 0 && p.min === 0;
};

/** 기한 지남이 되는 시각: 날짜만 정한 마감은 그날이 끝날 때 (앱과 같은 규칙) */
export const overdueAt = (ms) => (isDateOnly(ms) ? ms + DAY : ms);

/** 앱이 저장한 날짜 문자열 → epoch ms. 시간대 표시가 없으면(앱은 기기 시간으로 저장) 한국 시간으로 본다 */
export function parseAppDate(s) {
  if (typeof s !== 'string' || !s) return null;
  const v = s.replace(/(\.\d{3})\d+/, '$1');
  const ms = Date.parse(/(Z|[+-]\d\d:?\d\d)$/.test(v) ? v : `${v}+09:00`);
  return Number.isFinite(ms) ? ms : null;
}

/** epoch ms → 앱이 저장하는 모양의 날짜 문자열 (한국 시간, 시간대 표시 없음) */
export const appDate = (ms) => new Date(ms + KST).toISOString().replace('Z', '');

/** 루틴 체크 기록에 쓰는 날짜 키 'YYYY-MM-DD' */
export function dayKey(ms) {
  const p = kst(ms);
  return `${p.y}-${pad(p.m)}-${pad(p.d)}`;
}

export const formatTime = (h, min) => `${pad(h)}:${pad(min)}`;

/** "11월 25일 (수)" */
export function formatDate(ms) {
  const p = kst(ms);
  return `${p.m}월 ${p.d}일 (${WEEKDAYS[p.wd - 1]})`;
}

/** 날짜만 정했으면 "11월 25일 (수)", 시간도 정했으면 "11월 25일 (수) 15:00" (앱 메시지와 같은 모양) */
export function formatDue(ms) {
  if (isDateOnly(ms)) return formatDate(ms);
  const p = kst(ms);
  return `${formatDate(ms)} ${formatTime(p.h, p.min)}`;
}

/** 루틴 요일 표시: "매일", "평일", "주말", "월·수·금" */
export function weekdayLabel(days) {
  const s = [...days].sort((a, b) => a - b).join('');
  if (s === '1234567') return '매일';
  if (s === '12345') return '평일';
  if (s === '67') return '주말';
  return [...days].sort((a, b) => a - b).map((d) => WEEKDAYS[d - 1]).join('·');
}
