// 텔레그램으로 보낸 문장에서 업무 이름·마감 일시(또는 루틴 요일·시각)를 뽑는다 (규칙 기반, 한국 시간)
// 예) "내일 3시까지 보고서 제출" → { title: '보고서 제출', dueAt: 내일 15:00 }

import { DAY, WEEKDAYS, kst, kstMs, startOfDay } from './kst.js';

const DAY_WORDS = { 오늘: 0, 금일: 0, 내일: 1, 낼: 1, 모레: 2, 글피: 3 };
const TAIL = '(?:까지|에는|에|부터)?';
const WD = '[월화수목금토일]';

/** 시각 표현 하나를 찾는다 → { h, min, match } */
function findTime(text) {
  let m = new RegExp(`(\\d{1,2}):(\\d{2})${TAIL}`).exec(text);
  if (m && +m[1] < 24 && +m[2] < 60) return { h: +m[1], min: +m[2], match: m[0] };
  m = new RegExp(`(?:(오전|오후|아침|점심|낮|저녁|밤|새벽)\\s*)?(\\d{1,2})\\s*시(?:\\s*(\\d{1,2})\\s*분|\\s*(반))?${TAIL}`).exec(text);
  if (m && +m[2] <= 24) {
    let h = +m[2] % 24;
    const part = m[1];
    if (['오후', '저녁', '밤'].includes(part) && h < 12) h += 12;
    else if (['점심', '낮'].includes(part) && h <= 5) h += 12;
    else if (['오전', '아침', '새벽'].includes(part) && h === 12) h = 0;
    else if (!part && h >= 1 && h <= 7) h += 12; // "3시"는 오후 3시로 본다
    return { h, min: m[4] ? 30 : Math.min(+(m[3] ?? 0), 59), match: m[0] };
  }
  m = new RegExp(`(정오)${TAIL}`).exec(text);
  return m ? { h: 12, min: 0, match: m[0] } : null;
}

/** 날짜 표현 하나를 찾는다 → { day: 그날 0시(ms), match } */
function findDate(text, now) {
  const today = kst(now);
  const at = (y, m, d) => kstMs(y, m, d);
  const upcoming = (m, d) => (at(today.y, m, d) < startOfDay(now) ? at(today.y + 1, m, d) : at(today.y, m, d));
  let m = new RegExp(`(\\d{4})[./-](\\d{1,2})[./-](\\d{1,2})${TAIL}`).exec(text);
  if (m) return { day: at(+m[1], +m[2], +m[3]), match: m[0] };
  m = new RegExp(`(\\d{1,2})\\s*월\\s*(\\d{1,2})\\s*일${TAIL}`).exec(text);
  if (m) return { day: upcoming(+m[1], +m[2]), match: m[0] };
  m = new RegExp(`(?<![\\d:])(\\d{1,2})/(\\d{1,2})(?!\\d)${TAIL}`).exec(text);
  if (m) return { day: upcoming(+m[1], +m[2]), match: m[0] };
  m = new RegExp(`(\\d+)\\s*(일|주)\\s*(?:후|뒤)${TAIL}`).exec(text);
  if (m) return { day: startOfDay(now) + +m[1] * (m[2] === '주' ? 7 : 1) * DAY, match: m[0] };
  m = new RegExp(`(?<![가-힣])(${Object.keys(DAY_WORDS).join('|')})${TAIL}(?![가-힣])`).exec(text);
  if (m) return { day: startOfDay(now) + DAY_WORDS[m[1]] * DAY, match: m[0] };
  // "다음주 화요일", "이번주 금", "금요일"
  m = new RegExp(`(?:(이번\\s*주|금주|다음\\s*주|담주|차주|다다음\\s*주)\\s*)?(${WD})(?:요일)?${TAIL}(?![가-힣])`).exec(text);
  if (m && (m[1] || /요일/.test(m[0]))) {
    const wd = WEEKDAYS.indexOf(m[2]) + 1;
    const monday = startOfDay(now) - (today.wd - 1) * DAY;
    const weeks = !m[1] ? null : /다다음/.test(m[1]) ? 2 : /다음|담|차/.test(m[1]) ? 1 : 0;
    if (weeks === null) return { day: startOfDay(now) + ((wd - today.wd + 7) % 7) * DAY, match: m[0] };
    return { day: monday + (weeks * 7 + wd - 1) * DAY, match: m[0] };
  }
  m = new RegExp(`(?:(이번|다음)\\s*)?주말${TAIL}`).exec(text);
  if (m) {
    const sat = startOfDay(now) + ((6 - today.wd + 7) % 7) * DAY;
    return { day: sat + (m[1] === '다음' ? 7 * DAY : 0), match: m[0] };
  }
  m = new RegExp(`(?<![\\d월])(\\d{1,2})\\s*일${TAIL}(?![가-힣])`).exec(text);
  if (m && +m[1] >= 1 && +m[1] <= 31) {
    const d = +m[1];
    const day = d < today.d ? at(today.y, today.m + 1, d) : at(today.y, today.m, d);
    return { day, match: m[0] };
  }
  return null;
}

const tidy = (s) => s.replace(/\s+/g, ' ').trim()
  .replace(/^(?:까지|에는|에|부터|마감)\s+/, '').replace(/\s+(?:까지|마감)$/, '').trim();

/**
 * 할 일 문장 해석. 날짜만 있으면 날짜만 정한 마감(그날 0시), 시각만 있으면 오늘(지났으면 내일).
 * @returns {{ title: string, dueAt: number|null }}
 */
export function parseTask(text, now = Date.now()) {
  let rest = ` ${text ?? ''} `;
  const date = findDate(rest, now);
  if (date) rest = rest.replace(date.match, ' ');
  const time = findTime(rest);
  if (time) rest = rest.replace(time.match, ' ');
  let dueAt = null;
  if (date) dueAt = date.day + (time ? (time.h * 60 + time.min) * 60_000 : 0);
  else if (time) {
    dueAt = startOfDay(now) + (time.h * 60 + time.min) * 60_000;
    if (dueAt <= now) dueAt += DAY;
  }
  return { title: tidy(rest).slice(0, 200), dueAt };
}

/**
 * 루틴 문장 해석 (수정용). 들어 있는 것만 돌려준다.
 * 예) "월수금 7시 운동" → { name: '운동', weekdays: [1,3,5], hour: 19, minute: 0 }
 */
export function parseRoutine(text) {
  let rest = ` ${text ?? ''} `;
  let weekdays = null;
  const m = new RegExp(`(매일|평일|주말|${WD}(?:[,·/]?${WD})+(?:요일)?|${WD}요일(?:[,·/\\s]*${WD}요일)*)(?:마다)?`).exec(rest);
  if (m) {
    weekdays = m[1] === '매일' ? [1, 2, 3, 4, 5, 6, 7] : m[1] === '평일' ? [1, 2, 3, 4, 5]
      : m[1] === '주말' ? [6, 7]
        : [...new Set([...m[1].replace(/요일/g, '')].filter((c) => WEEKDAYS.includes(c)).map((c) => WEEKDAYS.indexOf(c) + 1))]
          .sort((a, b) => a - b);
    rest = rest.replace(m[0], ' ');
  }
  const time = findTime(rest);
  if (time) rest = rest.replace(time.match, ' ');
  return { name: tidy(rest).slice(0, 200), weekdays, hour: time?.h ?? null, minute: time?.min ?? null };
}
