import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';
import { sha256Hex } from '../src/crypto.js';
import { replaceReminders } from '../src/db.js';
import worker from '../src/index.js';
import { sendDueReminders } from '../src/telegram.js';
import { fakeD1 } from './support/d1.js';

let env;
const realFetch = globalThis.fetch;
const tokens = {};
const DEV_A = 'device_aaaaaaaa';
const DEV_B = 'device_bbbbbbbb';

async function addUser(id) {
  tokens[id] = `tok_${id}`.padEnd(40, 'x');
  env.DB.exec(`INSERT INTO users (id, google_sub, email, created_at) VALUES ('${id}', 'g_${id}', '${id}@x.com', 0);
    INSERT INTO sessions (token_hash, user_id, created_at, last_used_at)
    VALUES ('${await sha256Hex(tokens[id])}', '${id}', ${Date.now()}, ${Date.now()});`);
}
const call = async (id, method, path, body) => {
  const res = await worker.fetch(new Request(`https://bot.test${path}`, {
    method, headers: { Authorization: `Bearer ${tokens[id]}` }, body: body ? JSON.stringify(body) : undefined,
  }), env);
  return { status: res.status, body: await res.json() };
};
const task = (id, data, deleted = false) => ({ id, parentId: null, position: 0, data: JSON.stringify(data), deleted });
const sync = (device, tasks) => call('u_1', 'POST', '/api/sync', { since: 0, device, changes: { tasks } });
const inbox = async (device) => (await call('u_1', 'GET', `/api/notifications?device=${device}`)).body;

beforeEach(async () => {
  env = { DB: fakeD1(), ALLOWED_EMAILS: 'u_1@x.com,u_2@x.com', BOT_TOKEN: '1:t' };
  await addUser('u_1');
  await addUser('u_2');
});
afterEach(() => {
  globalThis.fetch = realFetch;
});

test('닉네임을 정하면 4자리 태그가 붙고, 바꿔도 태그는 유지된다', async () => {
  assert.deepEqual((await call('u_1', 'GET', '/api/profile')).body, { nickname: '', tag: '', bio: '', avatar: null });
  const first = (await call('u_1', 'PUT', '/api/profile', { nickname: '  문 다니엘 ' })).body;
  assert.equal(first.nickname, '문 다니엘');
  assert.match(first.tag, /^\d{4}$/);

  const other = (await call('u_2', 'PUT', '/api/profile', { nickname: '문 다니엘' })).body;
  assert.notEqual(other.tag, first.tag, '같은 닉네임이면 다른 태그');

  const renamed = (await call('u_1', 'PUT', '/api/profile', { nickname: '다니엘', bio: '안녕하세요' })).body;
  assert.deepEqual([renamed.tag, renamed.tagChanged, renamed.bio], [first.tag, false, '안녕하세요']);

  // 새 닉네임에서 같은 태그를 이미 다른 사람이 쓰면 새 태그를 받는다
  env.DB.exec(`UPDATE users SET nickname = '겹침', tag = '${first.tag}' WHERE id = 'u_2'`);
  const moved = (await call('u_1', 'PUT', '/api/profile', { nickname: '겹침' })).body;
  assert.equal(moved.tagChanged, true);
  assert.notEqual(moved.tag, first.tag);
});

test('잘못된 닉네임·긴 자기소개·큰 사진은 거부하고, 사진은 저장·삭제할 수 있다', async () => {
  assert.equal((await call('u_1', 'PUT', '/api/profile', { nickname: '문#1234' })).status, 400);
  assert.equal((await call('u_1', 'PUT', '/api/profile', { bio: '자기소개' })).status, 400, '닉네임 먼저');
  await call('u_1', 'PUT', '/api/profile', { nickname: '다니엘' });
  assert.equal((await call('u_1', 'PUT', '/api/profile', { bio: '가'.repeat(151) })).status, 400);
  const big = `data:image/jpeg;base64,${'A'.repeat(300_000)}`;
  assert.equal((await call('u_1', 'PUT', '/api/profile', { avatar: big })).status, 400);

  const photo = 'data:image/jpeg;base64,/9j/4AAQSkZJRg==';
  assert.equal((await call('u_1', 'PUT', '/api/profile', { avatar: photo })).body.avatar, photo);
  assert.equal((await call('u_1', 'PUT', '/api/profile', { avatar: null })).body.avatar, null);
});

test('다른 기기에서 바꾼 할 일만 알림함에 보이고, 누르면 읽음 처리된다', async () => {
  await sync(DEV_A, [task('t1', { title: '보고서', isDone: false })]);
  assert.equal((await inbox(DEV_A)).items.length, 0, '내가 바꾼 건 내 기기에서는 안 보인다');
  let b = await inbox(DEV_B);
  assert.deepEqual([b.unread, b.items[0].title, b.items[0].body, b.items[0].target], [1, '할 일 추가', '보고서', 'task:t1']);

  await sync(DEV_A, [task('t1', { title: '보고서 v2', isDone: false })]);
  await sync(DEV_A, [task('t1', { title: '보고서 v2', isDone: true })]);
  await sync(DEV_A, [task('t1', { title: '보고서 v2', isDone: true }, true)]);
  b = await inbox(DEV_B);
  assert.deepEqual(b.items.map((i) => i.title), ['할 일 삭제', '할 일 완료', '할 일 수정', '할 일 추가'].slice(0, 4));
  assert.equal(b.items[0].target, null, '삭제된 할 일은 열 화면이 없다');

  await call('u_1', 'POST', '/api/notifications/read', { ids: [b.items[0].id] });
  assert.equal((await inbox(DEV_B)).unread, 3);
  await call('u_1', 'POST', '/api/notifications/read', { all: true, device: DEV_B });
  assert.equal((await inbox(DEV_B)).unread, 0);
});

test('한 번에 많이 바뀌면 하나로 묶고, 순서만 바뀐 것은 알리지 않는다', async () => {
  await sync(DEV_A, Array.from({ length: 8 }, (_, i) => task(`t${i}`, { title: `할 일 ${i}` })));
  const b = await inbox(DEV_B);
  assert.equal(b.items.length, 1);
  assert.equal(b.items[0].title, '다른 기기에서 할 일 8개가 바뀌었어요');

  await sync(DEV_A, [{ ...task('t0', { title: '할 일 0' }), position: 5 }]);
  assert.equal((await inbox(DEV_B)).items.length, 1);
});

test('보낸 리마인더가 알림함에 한 번 남고, 누르면 그 할 일로 간다', async () => {
  env.DB.exec(`INSERT INTO links (code, chat_id, chat_name, created_at, user_id) VALUES ('u_1', 100, '문', 0, 'u_1');`);
  await replaceReminders(env, 'u_1', [{
    key: 'task:t1:x', fireAt: Date.now() - 1000, dueAt: Date.now() + 3600000,
    text: '[체크리스트 업무] 보고서\n[알림시각] 10월 6일 (화) 17:30',
    buttons: [{ text: '📱 앱에서 보기', url: 'https://app.test/?open=task:t1' }],
  }]);
  globalThis.fetch = async () => new Response(JSON.stringify({ ok: true, result: {} }), { status: 200 });
  await sendDueReminders(env);
  await sendDueReminders(env);
  const items = (await inbox(DEV_B)).items;
  assert.equal(items.length, 1);
  assert.deepEqual([items[0].title, items[0].body, items[0].target], ['🔔 보고서', '[알림시각] 10월 6일 (화) 17:30', 'task:t1']);
  assert.equal((await inbox(DEV_A)).items.length, 1, '리마인더는 모든 기기에 보인다');
});
