// 할 일·메모 → 노션 페이지 속성과 본문 (사용자가 고른 매핑대로)
// - 메모: 제목·내용(앞 200자)·날짜(작성일)·처음 상태(새로 만들 때만), 본문 = 내용 전체
// - 할 일: 제목·완료·날짜(마감)·내용(설명·메모 요약), 본문 = 설명, 세부 체크리스트, 메모

import { isDateOnly, parseAppDate } from './kst.js';

/** 노션 글 조각 하나의 최대 길이 */
const TEXT_MAX = 2000;
/** 노션 '내용' 속성에 넣는 요약 길이 */
export const SUMMARY_MAX = 200;

const text = (s) => [{ type: 'text', text: { content: s } }];
const summary = (s) => (s.length > SUMMARY_MAX ? `${s.slice(0, SUMMARY_MAX - 1)}…` : s);
const firstLine = (s) => s.split('\n').map((l) => l.trim()).find(Boolean)?.slice(0, 100) ?? '';

/** 앱 날짜 문자열 → 노션 날짜 (날짜만 정했으면 'YYYY-MM-DD', 시간도 있으면 한국 시간) */
export function notionDate(s) {
  const ms = parseAppDate(s);
  if (ms == null) return null;
  const local = new Date(ms + 9 * 3600 * 1000).toISOString();
  return isDateOnly(ms) ? local.slice(0, 10) : `${local.slice(0, 19)}+09:00`;
}

const dateProp = (s) => {
  const start = notionDate(s);
  return { date: start ? { start } : null };
};
const choice = (type, name) => ({ [type]: name ? { name } : null });

/** 메모 → 속성 (처음 상태는 새로 만들 때만, 고칠 때는 노션에서 바꾼 상태를 그대로 둔다) */
export function memoProperties(memo, map, { isNew }) {
  const content = String(memo.content ?? '');
  const props = { [map.title]: { title: text(String(memo.title ?? '').trim() || firstLine(content) || '제목 없음') } };
  if (map.content) props[map.content] = { rich_text: content ? text(summary(content)) : [] };
  if (map.date) props[map.date] = dateProp(memo.createdAt);
  if (isNew && map.status) props[map.status.prop] = choice(map.status.type, map.status.value);
  return props;
}

/** 할 일 설명과 메모들 (내용 요약·본문에 쓴다) */
const taskText = (task, notes) =>
  [String(task.description ?? '').trim(), ...notes.map((n) => String(n.content ?? '').trim())].filter(Boolean);

/** 할 일 → 속성. [notes]는 이 할 일의 메모들 */
export function taskProperties(task, notes, map) {
  const props = { [map.title]: { title: text(String(task.title ?? '').trim() || '제목 없음') } };
  const done = task.isDone === true;
  if (map.done) {
    props[map.done.prop] = map.done.type === 'checkbox'
      ? { checkbox: done }
      : choice(map.done.type, done ? map.done.doneValue : map.done.todoValue);
  }
  if (map.date) props[map.date] = dateProp(task.dueDate);
  if (map.content) props[map.content] = { rich_text: text(summary(taskText(task, notes).join('\n'))) };
  return props;
}

const paragraphs = (s) => {
  const blocks = [];
  for (let i = 0; i < s.length; i += TEXT_MAX) {
    blocks.push({ object: 'block', type: 'paragraph', paragraph: { rich_text: text(s.slice(i, i + TEXT_MAX)) } });
  }
  return blocks;
};

/** 메모 본문: 내용 전체를 2000자씩 나눈 문단들 (줄바꿈은 그대로) */
export const memoBody = (memo) => paragraphs(String(memo.content ?? '')).slice(0, 100);

/** 할 일 본문: 설명 → 세부 체크리스트(할 일 블록) → 메모 */
export function taskBody(task, subTasks, notes) {
  const description = String(task.description ?? '').trim();
  const blocks = [
    ...paragraphs(description),
    ...subTasks.map((s) => ({
      object: 'block', type: 'to_do',
      to_do: { rich_text: text(String(s.title ?? '').slice(0, TEXT_MAX)), checked: s.isDone === true },
    })),
    ...notes.flatMap((n) => paragraphs(String(n.content ?? '').trim())),
  ];
  return blocks.slice(0, 100);
}
