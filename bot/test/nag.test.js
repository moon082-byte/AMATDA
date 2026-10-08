import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';
import { sha256Hex } from '../src/crypto.js';
import { replaceReminders } from '../src/db.js';
import worker from '../src/index.js';
import { NAG_MAX_REPEATS, afterSend, nagKeyboard, nagText } from '../src/nag.js';
import { sendDueReminders, webhook, webhookSecret } from '../src/telegram.js';
import { telegramRoute } from '../src/tg_routes.js';
import { fakeD1 } from './support/d1.js';

let env;
let calls;
const realFetch = globalThis.fetch;
const now = () => Date.now();
const item = (key = 'task:t1:x') => ({
  key,
  fireAt: now() - 1000,
  dueAt: now() + 60 * 60 * 1000,
  text: '[체크리스트 업무] 보고서',
  buttons: [{ text: '📱 앱에서 보기', url: 'https://app.test/?open=task:t1' }],
});
const sent = () => calls.filter((c) => c.method === 'sendMessage');
const reminder = () => env.DB.rows('SELECT * FROM reminders')[0];
const due = () => env.DB.exec('UPDATE reminders SET next_at = 0 WHERE next_at IS NOT NULL');

beforeEach(async () => {
  env = { DB: fakeD1(), BOT_TOKEN: '123:test' };
  env.DB.exec(`INSERT INTO users (id, google_sub, email, created_at) VALUES ('u_1', 'g1', 'a@b.c', 0);
    INSERT INTO links (code, chat_id, chat_name, created_at, user_id) VALUES ('u_1', 100, '문', 0, 'u_1');`);
  calls = [];
  globalThis.fetch = async (url, init) => {
    calls.push({ method: String(url).split('/').pop(), body: JSON.parse(init.body) });
    return new Response(JSON.stringify({ ok: true, result: {} }), { status: 200 });
  };
  await replaceReminders(env, 'u_1', [item()]);
});
afterEach(() => {
  globalThis.fetch = realFetch;
});

test('확인을 누를 때까지 5분마다 최대 3번 더 보낸다', async () => {
  await sendDueReminders(env);
  assert.equal(sent().length, 1);
  const [row] = sent()[0].body.reply_markup.inline_keyboard;
  const ack = reminder().ack_id;
  assert.deepEqual(row[0], { text: '✅ 확인', callback_data: `ack:${ack}` });
  assert.equal(row[1].url, `https://app.test/?open=task:t1&ack=${ack}`);
  assert.ok(reminder().next_at > now() + 4 * 60 * 1000, '5분 뒤에 다시 보낸다');

  await sendDueReminders(env);
  assert.equal(sent().length, 1, '5분이 지나기 전에는 보내지 않는다');

  for (let i = 0; i < 5; i++) {
    due();
    await sendDueReminders(env);
  }
  assert.equal(sent().length, 1 + NAG_MAX_REPEATS);
  assert.match(sent()[1].body.text, /^🔁 다시 알림 \(2\/4\)\n\[체크리스트 업무\]/);
  assert.match(sent()[3].body.text, /^🔁 다시 알림 \(4\/4\)/);
  assert.equal(reminder().next_at, null);
});

test('앱이 일정을 다시 올려도 보냄·다시 보낸 횟수는 유지된다', async () => {
  await sendDueReminders(env);
  due();
  await sendDueReminders(env);
  const before = reminder();
  await replaceReminders(env, 'u_1', [item()]);
  assert.equal(reminder().sent, 1);
  assert.equal(reminder().repeats, 1);
  assert.equal(reminder().next_at, before.next_at);
  assert.equal(reminder().ack_id, before.ack_id, '확인값은 알림마다 고정');
});

test('텔레그램 [✅ 확인]을 누르면 멈추고 버튼이 확인함으로 바뀐다', async () => {
  await sendDueReminders(env);
  const ack = reminder().ack_id;
  const keyboard = sent()[0].body.reply_markup;
  const press = (chatId) => webhook(new Request('https://bot.test/telegram/webhook', {
    method: 'POST',
    headers: { 'X-Telegram-Bot-Api-Secret-Token': secret },
    body: JSON.stringify({ callback_query: {
      id: 'cq1', data: `ack:${ack}`,
      message: { message_id: 7, chat: { id: chatId }, reply_markup: keyboard },
    } }),
  }), env);
  const secret = await webhookSecret(env);

  await press(999); // 다른 대화방에서는 끌 수 없다
  assert.equal(reminder().acked, 0);
  await press(100);
  assert.equal(reminder().acked, 1);
  const answer = calls.filter((c) => c.method === 'answerCallbackQuery').at(-1);
  assert.match(answer.body.text, /다시 알리지 않을게요/);
  const edit = calls.find((c) => c.method === 'editMessageReplyMarkup');
  assert.deepEqual(edit.body.reply_markup.inline_keyboard[0][0], { text: '✅ 확인함', callback_data: 'done' });

  due();
  await sendDueReminders(env);
  assert.equal(sent().length, 1, '확인한 알림은 다시 보내지 않는다');
});

test('앱에서 [앱에서 보기]로 열면 그 계정의 알림만 끌 수 있다', async () => {
  await sendDueReminders(env);
  const ack = reminder().ack_id;
  const post = (userId, body) => telegramRoute('/api/reminders/ack', 'POST', { id: userId },
    new Request('https://bot.test', { method: 'POST', body: JSON.stringify(body) }), env);
  assert.deepEqual(await post('u_2', { ack }), [{ ok: false }]);
  assert.deepEqual(await post('u_1', { ack: 'nope' }), [{ ok: false }]);
  assert.deepEqual(await post('u_1', { ack }), [{ ok: true }]);
  due();
  await sendDueReminders(env);
  assert.equal(sent().length, 1);
});

test('앱의 끄기 요청은 실제 주소(/api/reminders/ack)로 로그인 확인을 거쳐 처리된다', async () => {
  env.ALLOWED_EMAILS = 'a@b.c';
  const token = 'tok_'.padEnd(40, 'x');
  env.DB.exec(`INSERT INTO sessions (token_hash, user_id, created_at, last_used_at)
    VALUES ('${await sha256Hex(token)}', 'u_1', ${now()}, ${now()})`);
  await sendDueReminders(env);
  const call = (auth) => worker.fetch(new Request('https://bot.test/api/reminders/ack', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json', ...(auth ? { Authorization: `Bearer ${token}` } : {}) },
    body: JSON.stringify({ ack: reminder().ack_id }),
  }), env);
  assert.equal((await call(false)).status, 401);
  const res = await call(true);
  assert.equal(res.status, 200);
  assert.deepEqual(await res.json(), { ok: true });
  assert.equal(reminder().acked, 1);
});

test('끈질긴 알림을 끄면 한 번만 보내고 [확인] 버튼·확인값도 붙이지 않는다', async () => {
  const put = (enabled) => telegramRoute('/api/telegram/nag', 'PUT', { id: 'u_1' },
    new Request('https://bot.test', { method: 'PUT', body: JSON.stringify({ enabled }) }), env);
  assert.deepEqual(await put(false), [{ nag: false }]);
  const [status] = await telegramRoute('/api/telegram', 'GET', { id: 'u_1' }, null, env);
  assert.equal(status.nag, false);

  await sendDueReminders(env);
  const row = sent()[0].body.reply_markup.inline_keyboard[0];
  assert.deepEqual(row, [{ text: '📱 앱에서 보기', url: 'https://app.test/?open=task:t1' }]);
  assert.equal(reminder().next_at, null);
});

test('순수 함수: 문구·버튼·다음 상태', () => {
  assert.equal(nagText('a', 1), 'a');
  assert.equal(nagText('a', 3), '🔁 다시 알림 (3/4)\na');
  assert.equal(nagKeyboard(null, null), undefined);
  assert.equal(nagKeyboard('깨진 값', 'f'.repeat(24)).inline_keyboard[0].length, 1);
  const first = afterSend({ code: 'c', key: 'k', sent: 0, repeats: 0 }, true, 1000);
  assert.deepEqual(first, { code: 'c', key: 'k', repeats: 0, next_at: 1000 + 5 * 60 * 1000 });
  assert.equal(afterSend({ code: 'c', key: 'k', sent: 1, repeats: 2 }, true, 0).next_at, null);
  assert.equal(afterSend({ code: 'c', key: 'k', sent: 0, repeats: 0 }, false, 0).next_at, null);
});
