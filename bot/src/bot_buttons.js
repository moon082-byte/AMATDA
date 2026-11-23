// 텔레그램 봇 일정 관리 버튼
// - ba:<초안> 등록·수정 확인, bc:<초안> 취소
// - be:<t|r>:<id> 수정할 내용 묻기, bd:<t|r>:<id> 삭제할지 묻기, by:<t|r>:<id> 삭제, bn 삭제 취소

import { putDraft, routineSummary, send, taskSummary } from './bot_flow.js';
import { addTask, chatAccount, deleteItem, findItem, updateRoutine, updateTask } from './bot_store.js';
import { parseAppDate } from './kst.js';
import { tg } from './telegram.js';

const PATTERN = /^(?:(ba|bc):([a-z0-9]+)|(be|bd|by):([tr]):(.+)|(bn))$/;

/** 일정 관리 버튼이면 처리하고 true */
export async function handleScheduleButton(env, cq) {
  const m = PATTERN.exec(cq.data ?? '');
  if (!m) return false;
  const chatId = cq.message?.chat?.id;
  const answer = (text) => tg(env, 'answerCallbackQuery', { callback_query_id: cq.id, ...(text ? { text } : {}) });
  // 버튼이 달린 메시지 글을 바꾸고 버튼을 없앤다
  const replace = (text) => cq.message && tg(env, 'editMessageText', {
    chat_id: chatId, message_id: cq.message.message_id, text, reply_markup: { inline_keyboard: [] },
  });
  const user = await chatAccount(env, chatId);
  if (!user) {
    await answer('계정 연결을 확인해 주세요');
    return true;
  }
  const [, draftAction, draftId, itemAction, itemKind, itemId, cancelDelete] = m;
  if (cancelDelete) {
    await answer();
    await replace('삭제를 취소했어요.');
    return true;
  }
  if (draftAction) {
    const draft = await env.DB.prepare('DELETE FROM bot_drafts WHERE id = ? AND chat_id = ? AND user_id = ? RETURNING *')
      .bind(draftId, chatId, user.id).first();
    if (!draft) {
      await answer('지난 요청이에요. 다시 보내 주세요');
      return true;
    }
    await answer();
    if (draftAction === 'bc') return !!(await replace('취소했어요.'));
    const data = JSON.parse(draft.data);
    if (draft.kind === 'add') {
      await addTask(env, user.id, data);
      await replace(`✅ 등록했어요. 앱에도 바로 반영돼요.\n\n${taskSummary(data)}`);
      return true;
    }
    const item = await findItem(env, user.id, draft.item_kind, draft.item_id);
    if (!item) return !!(await replace('이미 지웠거나 바꿀 수 없는 항목이에요.'));
    if (draft.item_kind === 't') await updateTask(env, user.id, item, data);
    else await updateRoutine(env, user.id, item, data);
    await replace(`✅ 수정했어요. 앱에도 바로 반영돼요.\n\n${draft.item_kind === 't' ? taskSummary(data) : routineSummary(data)}`);
    return true;
  }

  const item = await findItem(env, user.id, itemKind, itemId);
  if (!item) {
    await answer('이미 지웠거나 바꿀 수 없는 항목이에요');
    return true;
  }
  await answer();
  const summary = itemKind === 't'
    ? taskSummary({ title: item.data.title, dueAt: parseAppDate(item.data.dueDate) })
    : routineSummary({ name: item.data.name, weekdays: item.data.weekdays ?? [], hour: item.data.hour ?? 9, minute: item.data.minute ?? 0 });
  if (itemAction === 'be') {
    await putDraft(env, { userId: user.id, chatId, kind: 'wait', itemKind, itemId });
    const example = itemKind === 't' ? '모레 5시 / 보고서 초안 / 모레 5시 보고서 초안 / 마감 없음' : '월수금 7시 / 저녁 운동 / 평일 8시 30분';
    await send(env, chatId, `✏️ 수정할 항목\n${summary}\n\n바꿀 내용을 보내 주세요. 바꾸는 부분만 쓰면 돼요.\n예) ${example}`,
      null, { reply_markup: { force_reply: true, input_field_placeholder: '바꿀 내용' } });
  } else if (itemAction === 'bd') {
    await send(env, chatId, `🗑 이 항목을 삭제할까요?\n${summary}`, [[
      { text: '🗑 삭제', callback_data: `by:${itemKind}:${itemId}` }, { text: '취소', callback_data: 'bn' },
    ]]);
  } else {
    await deleteItem(env, user.id, itemKind, item);
    await replace(`🗑 삭제했어요. 앱에서도 바로 지워져요.\n${summary}`);
  }
  return true;
}
