// 텔레그램 봇 일정 조회: /all 전체, /today 오늘, /week 이번 주(월~일), /month 이번 달
// 할일과 루틴을 나눠 보여주고, 항목마다 [✏️ 수정][🗑 삭제] 버튼을 단다 (프로젝트 배정 업무는 바꿀 수 없어 버튼 없음)

import {
  DAY, dayKey, formatDate, formatDue, formatTime, isDateOnly, kst, kstMs, overdueAt, startOfDay, weekdayLabel,
} from './kst.js';

/** 한 메시지에 보여주는 최대 항목 수 (버튼이 너무 많아지지 않게) */
export const MAX_ITEMS = 20;

export const RANGES = {
  today: { title: '오늘 일정', range: (now) => [startOfDay(now), startOfDay(now) + DAY] },
  week: {
    title: '이번 주 일정',
    range: (now) => {
      const monday = startOfDay(now) - (kst(now).wd - 1) * DAY;
      return [monday, monday + 7 * DAY];
    },
  },
  month: {
    title: '이번 달 일정',
    range: (now) => {
      const p = kst(now);
      return [kstMs(p.y, p.m, 1), kstMs(p.y, p.m + 1, 1)];
    },
  },
  all: { title: '전체 일정', range: () => [-Infinity, Infinity] },
};

const open = (t) => !t.isDone && !t.missedAt;
const isProject = (t) => t.id.startsWith('pt_') || !!t.project;
const fits = (data) => new TextEncoder().encode(data).length <= 64;

/**
 * 조회 결과 메시지와 버튼.
 * @param {{tasks: object[], routines: object[]}} schedule bot_store.loadSchedule 결과
 */
export function buildList(schedule, kind, now = Date.now()) {
  const { title, range } = RANGES[kind];
  const [from, to] = range(now);
  const tasks = schedule.tasks.filter(open);
  const inRange = tasks.filter((t) => t.due != null && t.due >= from && t.due < to)
    .sort((a, b) => a.due - b.due);
  // 오늘·전체 조회에는 이미 기한이 지난 할일을 따로 모아 보여준다
  const overdue = kind === 'today' || kind === 'all'
    ? tasks.filter((t) => t.due != null && overdueAt(t.due) <= now).sort((a, b) => a.due - b.due)
    : [];
  const shown = inRange.filter((t) => !overdue.includes(t));
  const noDue = kind === 'all' ? tasks.filter((t) => t.due == null) : [];
  const today = kst(now).wd;
  const routines = schedule.routines
    .filter((r) => kind !== 'today' || (r.weekdays ?? []).includes(today))
    .sort((a, b) => (a.hour * 60 + a.minute) - (b.hour * 60 + b.minute));

  const lines = [`📅 ${title}${kind === 'today' ? ` · ${formatDate(now)}` : ''}`];
  const keyboard = [];
  let n = 0;
  let hidden = 0;
  const item = (label, kindKey, entry, locked) => {
    if (n >= MAX_ITEMS) return hidden++;
    n++;
    lines.push(`${n}. ${label}`);
    const name = (entry.title ?? entry.name ?? '').slice(0, 20);
    const edit = `be:${kindKey}:${entry.id}`;
    const del = `bd:${kindKey}:${entry.id}`;
    if (!locked && fits(edit) && fits(del)) {
      keyboard.push([{ text: `✏️ ${n}. ${name}`, callback_data: edit }, { text: '🗑 삭제', callback_data: del }]);
    }
  };
  // 오늘 조회는 시각만 ("15:00", 날짜만 정했으면 "오늘 중")
  const due = (t) => {
    if (kind !== 'today') return formatDue(t.due);
    const p = kst(t.due);
    return isDateOnly(t.due) ? '오늘 중' : formatTime(p.h, p.min);
  };
  const task = (t, label = due(t)) => item(`${isProject(t) ? '📁 ' : ''}${t.title} · ${label}`, 't', t, isProject(t));

  if (shown.length || overdue.length || noDue.length) {
    lines.push('', '📋 할일');
    shown.forEach((t) => task(t));
    if (overdue.length) {
      lines.push('⏰ 기한 지남');
      overdue.forEach((t) => task(t, formatDue(t.due)));
    }
    if (noDue.length) {
      lines.push('📌 마감 없음');
      noDue.forEach((t) => task(t, '마감 없음'));
    }
  }
  if (routines.length) {
    lines.push('', '🔁 루틴');
    const doneKey = dayKey(now);
    for (const r of routines) {
      const time = formatTime(r.hour ?? 9, r.minute ?? 0);
      const label = kind === 'today'
        ? `${r.name} · ${time}${(r.doneDates ?? []).includes(doneKey) ? ' ✅' : ''}`
        : `${r.name} · ${weekdayLabel(r.weekdays ?? [])} ${time}`;
      item(label, 'r', r, false);
    }
  }
  if (n === 0) lines.push('', kind === 'all' ? '등록된 일정이 없어요.' : '이 기간에 등록된 일정이 없어요.');
  if (hidden) lines.push('', `외 ${hidden}개는 앱에서 확인해 주세요.`);
  if (n > 0) lines.push('', '✏️ 수정 · 🗑 삭제는 아래 버튼으로, 추가는 "내일 3시 보고서"처럼 보내 주세요.');
  return { text: lines.join('\n'), keyboard };
}
