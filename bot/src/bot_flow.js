// 텔레그램 봇 일정 관리: 조회 명령, 문장으로 할 일 추가, 수정할 내용 받기 (버튼 처리는 bot_buttons.js)
// - /all /today /week /month : 일정 조회 (할일·루틴 구분, 항목마다 [수정][삭제] 버튼)
// - /add 내일 3시 보고서 · 개인 대화방에서는 명령 없이 문장만 보내도 된다 → "이렇게 등록할까요?" 확인
// - 개인 대화방에서만 동작한다 (그룹방은 다른 사람이 내 일정을 보거나 바꿀 수 있어서)

import { buildList, RANGES } from './bot_list.js';
import { parseRoutine, parseTask } from './bot_parse.js';
import { chatAccount, findItem, loadSchedule } from './bot_store.js';
import { formatDue, formatTime, parseAppDate, weekdayLabel } from './kst.js';
import { tg } from './telegram.js';

/** 수정할 내용을 기다리는 시간 */
const WAIT_MS = 10 * 60 * 1000;
const KEEP_MS = 24 * 60 * 60 * 1000;

const TEXT = {
  group: '일정 조회·추가는 봇과의 개인 대화방에서 쓸 수 있어요.',
  notLinked: '아직 아맞다 계정과 연결되지 않았어요. 앱 설정에서 텔레그램을 연결해 주세요.',
  noTitle: '업무 이름을 알 수 없어요.\n예) 내일 3시 보고서 제출',
};

export const send = (env, chatId, text, keyboard, extra = {}) => tg(env, 'sendMessage', {
  chat_id: chatId, text, ...(keyboard ? { reply_markup: { inline_keyboard: keyboard } } : {}), ...extra,
});

/** 할 일 한 줄 요약: "📋 보고서 제출\n⏰ 11월 25일 (수) 15:00" */
export const taskSummary = ({ title, dueAt }) => `📋 ${title}\n⏰ ${dueAt == null ? '마감 없음' : formatDue(dueAt)}`;
export const routineSummary = ({ name, weekdays, hour, minute }) =>
  `🔁 ${name}\n⏰ ${weekdayLabel(weekdays)} ${formatTime(hour, minute)}`;

/** 확인 대기 내용을 저장하고 짧은 id를 돌려준다 */
export async function putDraft(env, { userId, chatId, kind, itemKind = null, itemId = null, data = null }) {
  const id = Array.from(crypto.getRandomValues(new Uint8Array(9)), (b) => b.toString(36).padStart(2, '0')).join('').slice(0, 16);
  await env.DB.batch([
    env.DB.prepare('DELETE FROM bot_drafts WHERE created_at < ? OR (chat_id = ? AND kind = ?)')
      .bind(Date.now() - KEEP_MS, chatId, 'wait'),
    env.DB.prepare(
      'INSERT INTO bot_drafts (id, user_id, chat_id, kind, item_kind, item_id, data, created_at) VALUES (?, ?, ?, ?, ?, ?, ?, ?)',
    ).bind(id, userId, chatId, kind, itemKind, itemId, data && JSON.stringify(data), Date.now()),
  ]);
  return id;
}

/** 일정 명령이면 처리하고 true */
export async function handleCommand(env, msg, cmd) {
  if (!RANGES[cmd.command] && cmd.command !== 'add') return false;
  const user = await accountOrExplain(env, msg.chat.id);
  if (!user) return true;
  if (cmd.command === 'add') {
    const text = (msg.text ?? '').replace(/^\/add(@\w+)?\s*/i, '');
    if (!text.trim()) await send(env, msg.chat.id, '추가할 일을 함께 보내 주세요.\n예) /add 내일 3시 보고서 제출');
    else await proposeAdd(env, user, msg.chat.id, text);
    return true;
  }
  const { text, keyboard } = buildList(await loadSchedule(env, user.id), cmd.command);
  await send(env, msg.chat.id, text, keyboard.length ? keyboard : null);
  return true;
}

/** 명령이 아닌 글: 수정할 내용을 기다리는 중이면 수정, 아니면 할 일 추가 (개인 대화방만) */
export async function handleText(env, msg) {
  const chatId = msg.chat.id;
  if (!(chatId > 0) || !msg.text?.trim()) return;
  const user = await accountOrExplain(env, chatId);
  if (!user) return;
  const wait = await env.DB.prepare(
    "DELETE FROM bot_drafts WHERE chat_id = ? AND kind = 'wait' RETURNING item_kind, item_id, created_at",
  ).bind(chatId).first();
  if (wait && wait.created_at > Date.now() - WAIT_MS) return proposeEdit(env, user, chatId, wait, msg.text);
  return proposeAdd(env, user, chatId, msg.text);
}

async function accountOrExplain(env, chatId) {
  if (!(chatId > 0)) {
    await send(env, chatId, TEXT.group);
    return null;
  }
  const user = await chatAccount(env, chatId);
  if (!user) await send(env, chatId, TEXT.notLinked);
  return user;
}

const confirmKeyboard = (id, ok) => [[{ text: ok, callback_data: `ba:${id}` }, { text: '취소', callback_data: `bc:${id}` }]];

async function proposeAdd(env, user, chatId, text) {
  const parsed = parseTask(text);
  if (!parsed.title) return send(env, chatId, TEXT.noTitle);
  const id = await putDraft(env, { userId: user.id, chatId, kind: 'add', data: parsed });
  return send(env, chatId, `${taskSummary(parsed)}\n\n이렇게 등록할까요?`, confirmKeyboard(id, '✅ 등록'));
}

/** 보낸 글에 들어 있는 부분만 바꾼다 ("마감 없음"이라고 쓰면 마감을 지운다) */
async function proposeEdit(env, user, chatId, wait, text) {
  const item = await findItem(env, user.id, wait.item_kind, wait.item_id);
  if (!item) return send(env, chatId, '이미 지웠거나 바꿀 수 없는 항목이에요.');
  let data;
  let before;
  if (wait.item_kind === 't') {
    const clear = /마감\s*없음/.test(text);
    const p = parseTask(text.replace(/마감\s*없음/, ' '));
    const old = { title: item.data.title, dueAt: parseAppDate(item.data.dueDate) };
    data = { title: p.title || old.title, dueAt: clear ? null : p.dueAt ?? old.dueAt };
    before = taskSummary(old);
  } else {
    const p = parseRoutine(text);
    const old = { name: item.data.name, weekdays: item.data.weekdays ?? [], hour: item.data.hour ?? 9, minute: item.data.minute ?? 0 };
    data = { name: p.name || old.name, weekdays: p.weekdays?.length ? p.weekdays : old.weekdays,
      hour: p.hour ?? old.hour, minute: p.minute ?? old.minute };
    before = routineSummary(old);
  }
  const id = await putDraft(env, { userId: user.id, chatId, kind: 'edit', itemKind: wait.item_kind, itemId: item.id, data });
  const after = wait.item_kind === 't' ? taskSummary(data) : routineSummary(data);
  return send(env, chatId, `바꾸기 전\n${before}\n\n바꾼 뒤\n${after}\n\n이렇게 바꿀까요?`, confirmKeyboard(id, '✅ 수정'));
}
