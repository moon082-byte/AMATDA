import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';
import { buildList } from '../src/bot_list.js';
import { parseRoutine, parseTask } from '../src/bot_parse.js';
import { loadSchedule } from '../src/bot_store.js';
import { DAY, appDate, formatDue, kstMs, parseAppDate, startOfDay } from '../src/kst.js';
import { webhook, webhookSecret } from '../src/telegram.js';
import { fakeD1 } from './support/d1.js';

let env;
let calls;
const realFetch = globalThis.fetch;
const CHAT = 100;
const sent = () => calls.filter((c) => c.method === 'sendMessage');
const last = () => sent().at(-1).body;
const rows = (sql) => env.DB.rows(sql);

const post = async (update) => webhook(new Request('https://bot.test/telegram/webhook', {
  method: 'POST',
  headers: { 'X-Telegram-Bot-Api-Secret-Token': await webhookSecret(env) },
  body: JSON.stringify(update),
}), env);
const say = (text, chatId = CHAT) => post({ message: { message_id: 1, chat: { id: chatId }, text } });
const press = (data, chatId = CHAT) =>
  post({ callback_query: { id: 'cq', data, message: { message_id: 9, chat: { id: chatId } } } });
/** 마지막 메시지의 버튼 중 [label]이 들어간 것 */
const button = (label) => last().reply_markup.inline_keyboard.flat().find((b) => b.text.includes(label)).callback_data;

function putRow(table, id, data, parentId = null) {
  env.DB.exec(`INSERT INTO ${table} (user_id, id, parent_id, position, data, deleted, version, updated_at)
    VALUES ('u_1', '${id}', ${parentId ? `'${parentId}'` : 'NULL'}, 0, '${JSON.stringify(data)}', 0, 1, 0)`);
}

beforeEach(() => {
  env = { DB: fakeD1(), BOT_TOKEN: '123:test', APP_URL: 'https://app.test/' };
  env.DB.exec(`INSERT INTO users (id, google_sub, email, created_at, version) VALUES ('u_1', 'g1', 'a@b.c', 0, 1);
    INSERT INTO links (code, chat_id, chat_name, created_at, user_id) VALUES ('u_1', ${CHAT}, '문', 0, 'u_1');`);
  calls = [];
  globalThis.fetch = async (url, init) => {
    calls.push({ method: String(url).split('/').pop(), body: JSON.parse(init.body) });
    return new Response(JSON.stringify({ ok: true, result: { message_id: 50 } }), { status: 200 });
  };
});
afterEach(() => {
  globalThis.fetch = realFetch;
});

test('문장 해석: 날짜·시각을 떼어 내고 남은 글이 업무 이름 (한국 시간)', () => {
  const now = kstMs(2026, 11, 24, 10); // 화요일 오전 10시
  const check = (text, title, due) => {
    const r = parseTask(text, now);
    assert.deepEqual([r.title, r.dueAt && formatDue(r.dueAt)], [title, due], text);
  };
  check('내일 3시 보고서 제출', '보고서 제출', '11월 25일 (수) 15:00');
  check('내일 3시까지 보고서 제출', '보고서 제출', '11월 25일 (수) 15:00');
  check('모레 오전 10시 반 회의', '회의', '11월 26일 (목) 10:30');
  check('다음주 월요일 9시 주간회의', '주간회의', '11월 30일 (월) 09:00');
  check('금요일 회의 준비', '회의 준비', '11월 27일 (금)');
  check('12월 3일 계약서 검토', '계약서 검토', '12월 3일 (목)');
  check('15:30 전화하기', '전화하기', '11월 24일 (화) 15:30');
  check('9시 출근 체크', '출근 체크', '11월 25일 (수) 09:00'); // 오늘 9시는 지나서 내일
  check('보고서 제출', '보고서 제출', null);
  assert.deepEqual(parseRoutine('월수금 7시 운동'), { name: '운동', weekdays: [1, 3, 5], hour: 19, minute: 0 });
  assert.deepEqual(parseRoutine('평일 아침 8시 30분').weekdays, [1, 2, 3, 4, 5]);
});

test('문장을 보내면 확인 후 등록하고, 앱 동기화 표·기한 지남 알림·알림함에 바로 들어간다', async () => {
  await say('내일 3시 보고서 제출');
  assert.match(last().text, /📋 보고서 제출\n⏰ .+ 15:00\n\n이렇게 등록할까요\?/);
  assert.equal(rows('SELECT * FROM tasks').length, 0, '확인 전에는 등록하지 않는다');

  await press(button('등록'));
  const [task] = rows('SELECT * FROM tasks');
  const data = JSON.parse(task.data);
  assert.equal(data.title, '보고서 제출');
  assert.equal(parseAppDate(data.dueDate), startOfDay(Date.now()) + DAY + 15 * 3600_000);
  assert.ok(!/Z$/.test(data.dueDate), '앱과 같은 모양 (시간대 표시 없음)');
  assert.ok(task.version > 1, '순번을 올려 앱이 다음 동기화에 받는다');
  assert.equal(rows("SELECT key FROM reminders WHERE key LIKE 'due:%'").length, 1);
  assert.equal(rows("SELECT title FROM notifications")[0].title, '텔레그램에서 할 일 추가');
  assert.match(calls.find((c) => c.method === 'editMessageText').body.text, /등록했어요/);

  await press(button('등록'));
  assert.equal(rows('SELECT * FROM tasks').length, 1, '같은 버튼을 다시 눌러도 한 번만');
});

test('/today: 할일·기한 지남·루틴을 나눠 보여주고, 프로젝트 업무에는 버튼이 없다', async () => {
  const now = Date.now();
  const today = startOfDay(now);
  putRow('tasks', 'task_a', { title: '오늘 할 일', dueDate: appDate(today + DAY - 60_000), isDone: false });
  putRow('tasks', 'task_late', { title: '어제 일', dueDate: appDate(today - DAY + 9 * 3600_000), isDone: false });
  putRow('tasks', 'task_done', { title: '끝낸 일', dueDate: appDate(today + 3600_000), isDone: true });
  putRow('tasks', 'pt_9', { title: '배정 업무', dueDate: appDate(today + DAY - 120_000), project: { roomId: 'r', taskId: '9' } });
  putRow('routines', 'routine_1', { name: '물 마시기', weekdays: [1, 2, 3, 4, 5, 6, 7], hour: 9, minute: 0, doneDates: [] });
  await say('/today');
  const { text, reply_markup } = last();
  assert.match(text, /📋 할일[\s\S]*오늘 할 일[\s\S]*⏰ 기한 지남[\s\S]*어제 일[\s\S]*🔁 루틴[\s\S]*물 마시기/);
  assert.ok(!text.includes('끝낸 일'));
  assert.ok(text.includes('📁 배정 업무'));
  const buttons = reply_markup.inline_keyboard.flat().map((b) => b.callback_data);
  assert.ok(buttons.includes('bd:t:task_a') && buttons.includes('be:r:routine_1'));
  assert.ok(!buttons.some((b) => b.includes('pt_9')), '프로젝트 업무는 바꿀 수 없다');

  const all = buildList(await loadSchedule(env, 'u_1'), 'all');
  assert.ok(all.text.includes('전체 일정') && all.text.includes('어제 일'));
});

test('[삭제] → 확인 → 할 일과 세부 항목·알림이 지워지고 다른 기기에도 삭제로 전달된다', async () => {
  putRow('tasks', 'task_a', { title: '지울 일', dueDate: null, isDone: false });
  putRow('sub_tasks', 'sub_1', { title: '세부', isDone: false }, 'task_a');
  env.DB.exec("INSERT INTO reminders (code, key, fire_at, due_at, text) VALUES ('u_1', 'task:task_a:x', 0, 0, 't')");
  await press('bd:t:task_a');
  assert.match(last().text, /삭제할까요\?\n📋 지울 일/);
  await press(button('삭제'));
  assert.deepEqual(rows("SELECT id, deleted FROM tasks UNION ALL SELECT id, deleted FROM sub_tasks").map((r) => r.deleted), [1, 1]);
  assert.equal(rows('SELECT * FROM reminders').length, 0);
  assert.equal(rows("SELECT title FROM notifications")[0].title, '텔레그램에서 할 일 삭제');
});

test('[수정] → 바꿀 내용 답장 → 확인 → 들어 있는 부분만 바뀐다 (할 일·루틴)', async () => {
  putRow('tasks', 'task_a', { title: '보고서', dueDate: appDate(startOfDay(Date.now()) + DAY), isDone: false, remindAt: ['x'] });
  await press('be:t:task_a');
  assert.equal(last().reply_markup.force_reply, true);
  await say('모레 5시');
  assert.match(last().text, /바꾼 뒤\n📋 보고서\n⏰ .+ 17:00/);
  await press(button('수정'));
  const data = JSON.parse(rows('SELECT data FROM tasks')[0].data);
  assert.equal(data.title, '보고서');
  assert.equal(parseAppDate(data.dueDate), startOfDay(Date.now()) + 2 * DAY + 17 * 3600_000);
  assert.deepEqual(data.remindAt, ['x'], '알림 시각은 그대로');

  putRow('routines', 'routine_1', { name: '운동', weekdays: [1], hour: 7, minute: 0 });
  await press('be:r:routine_1');
  await say('월수금 저녁 8시');
  await press(button('수정'));
  const r = JSON.parse(rows("SELECT data FROM routines")[0].data);
  assert.deepEqual([r.name, r.weekdays, r.hour], ['운동', [1, 3, 5], 20]);
});

test('그룹방에서는 일정을 보여주거나 바꾸지 않고, 연결 안 된 대화방은 안내한다', async () => {
  await say('/today', -500);
  assert.match(last().text, /개인 대화방/);
  const before = sent().length;
  await say('내일 3시 보고서', -500);
  assert.equal(sent().length, before, '그룹방의 일반 대화는 무시');
  await press('bd:t:task_a', -500);
  assert.equal(calls.at(-1).method, 'answerCallbackQuery');
  await say('내일 보고서', 777);
  assert.match(last().text, /연결되지 않았어요/);
});
