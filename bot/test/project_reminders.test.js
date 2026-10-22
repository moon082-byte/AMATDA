import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';
import { sha256Hex } from '../src/crypto.js';
import worker from '../src/index.js';
import { sendDueProjectReminders } from '../src/project_reminders.js';
import { fakeD1 } from './support/d1.js';

let env;
const realFetch = globalThis.fetch;
const tokens = {};

async function addUser(id, nickname, tag) {
  tokens[id] = `tok_${id}`.padEnd(40, 'x');
  env.DB.exec(`INSERT INTO users (id, google_sub, email, nickname, tag, created_at)
      VALUES ('${id}', 'g_${id}', '${id}@x.com', '${nickname}', '${tag}', 0);
    INSERT INTO sessions (token_hash, user_id, created_at, last_used_at)
      VALUES ('${await sha256Hex(tokens[id])}', '${id}', ${Date.now()}, ${Date.now()});`);
}
const call = async (id, method, path, body) => {
  const res = await worker.fetch(new Request(`https://bot.test${path}`, {
    method, headers: { Authorization: `Bearer ${tokens[id]}` }, body: body ? JSON.stringify(body) : undefined,
  }), env);
  return { status: res.status, body: await res.json() };
};
const titles = async (id) =>
  (await call(id, 'GET', '/api/notifications?device=dev_xxxxxxxx')).body.items.map((n) => `${n.title}|${n.body}`);

beforeEach(async () => {
  env = { DB: fakeD1(), ALLOWED_EMAILS: 'lead@x.com,a@x.com,b@x.com' };
  await addUser('lead', '팀장', '1111');
  await addUser('a', '에이', '2222');
  await addUser('b', '비', '3333');
  globalThis.fetch = async () => new Response('{}', { status: 200 });
});
afterEach(() => {
  globalThis.fetch = realFetch;
});

test('프로젝트 리마인더는 팀장과 진행 중 업무 담당자에게 한 번 간다', async () => {
  const room = (await call('lead', 'POST', '/api/project-rooms', { name: '신제품' })).body.room;
  for (const id of ['a', 'b']) {
    await call('lead', 'POST', `/api/project-rooms/${room.id}/invites`, { userId: id });
    await call(id, 'POST', `/api/project-rooms/${room.id}/accept`);
  }
  const past = Date.now() - 1000;
  const future = Date.now() + 3600_000;
  let d = (await call('lead', 'POST', `/api/project-rooms/${room.id}/projects`,
    { name: '디자인', remindAt: [future, past, past] })).body;
  const project = d.projects[0];
  assert.deepEqual(project.remindAt, [past, future], '겹치는 시각은 하나로, 이른 순');
  d = (await call('lead', 'POST', `/api/projects/${project.id}/tasks`, { title: '시안', assigneeId: 'a' })).body;
  const done = (await call('lead', 'POST', `/api/projects/${project.id}/tasks`, { title: '문구', assigneeId: 'b' }))
    .body.projects[0].tasks.find((t) => t.title === '문구');
  await call('b', 'POST', `/api/project-tasks/${done.id}/complete`);
  await call('lead', 'POST', `/api/project-tasks/${done.id}/approve`);

  await sendDueProjectReminders(env);
  await sendDueProjectReminders(env);
  const note = '프로젝트 리마인더|신제품방 - 디자인 · 남은 업무 1개';
  assert.equal((await titles('lead')).filter((t) => t === note).length, 1);
  assert.equal((await titles('a')).filter((t) => t === note).length, 1);
  assert.equal((await titles('b')).filter((t) => t === note).length, 0, '업무를 끝낸 사람은 받지 않는다');

  // 리마인더를 다시 저장해도 이미 보낸 시각은 다시 보내지 않는다
  await call('lead', 'PUT', `/api/projects/${project.id}`, { name: '디자인', remindAt: [past, future] });
  await sendDueProjectReminders(env);
  assert.equal((await titles('lead')).filter((t) => t === note).length, 1);
});

test('팀원은 프로젝트 리마인더를 바꿀 수 없고, 프로젝트를 지우면 리마인더도 지운다', async () => {
  const room = (await call('lead', 'POST', '/api/project-rooms', { name: '신제품' })).body.room;
  await call('lead', 'POST', `/api/project-rooms/${room.id}/invites`, { userId: 'a' });
  await call('a', 'POST', `/api/project-rooms/${room.id}/accept`);
  const project = (await call('lead', 'POST', `/api/project-rooms/${room.id}/projects`,
    { name: '디자인', remindAt: [Date.now() + 1000] })).body.projects[0];
  assert.equal((await call('a', 'PUT', `/api/projects/${project.id}`, { name: 'x', remindAt: [] })).status, 403);
  assert.equal((await call('lead', 'POST', `/api/project-rooms/${room.id}/projects`,
    { name: 'x', remindAt: [1, 2, 3, 4, 5, 6] })).status, 400, '최대 5개');
  await call('lead', 'DELETE', `/api/projects/${project.id}`);
  assert.equal(env.DB.rows('SELECT * FROM project_reminders').length, 0);
});
