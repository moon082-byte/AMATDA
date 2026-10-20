import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';
import { sha256Hex } from '../src/crypto.js';
import worker from '../src/index.js';
import { fakeD1 } from './support/d1.js';

let env;
let telegram;
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
const inbox = async (id) => (await call(id, 'GET', '/api/notifications?device=dev_xxxxxxxx')).body.items;

/** 팀장이 방을 만들고 팀원을 초대·수락시킨 상태 */
async function roomWithMember() {
  const room = (await call('lead', 'POST', '/api/project-rooms', { name: '신제품', goal: '11월 출시' })).body.room;
  await call('lead', 'POST', `/api/project-rooms/${room.id}/invites`, { userId: 'mem' });
  await call('mem', 'POST', `/api/project-rooms/${room.id}/accept`);
  const detail = (await call('lead', 'POST', `/api/project-rooms/${room.id}/projects`, { name: '디자인', dueAt: 1e12 })).body;
  return { roomId: room.id, projectId: detail.projects[0].id };
}

beforeEach(async () => {
  env = { DB: fakeD1(), ALLOWED_EMAILS: 'lead@x.com,mem@x.com,out@x.com', BOT_TOKEN: '1:t', APP_URL: 'https://app.test/' };
  await addUser('lead', '팀장', '1111');
  await addUser('mem', '팀원', '2222');
  await addUser('out', '외부', '3333');
  env.DB.exec(`INSERT INTO links (code, chat_id, chat_name, created_at, user_id) VALUES ('mem', 200, 'm', 0, 'mem');`);
  telegram = [];
  globalThis.fetch = async (url, init) => {
    telegram.push(JSON.parse(init.body));
    return new Response(JSON.stringify({ ok: true }), { status: 200 });
  };
});
afterEach(() => {
  globalThis.fetch = realFetch;
});

test('초대 → 수락해야 팀원이 되고, 초대받은 사람에게 알림함·텔레그램 알림이 간다', async () => {
  const room = (await call('lead', 'POST', '/api/project-rooms', { name: '신제품' })).body.room;
  const found = (await call('lead', 'GET', `/api/users/lookup?handle=${encodeURIComponent('팀원#2222')}`)).body;
  assert.equal(found.userId, 'mem');
  await call('lead', 'POST', `/api/project-rooms/${room.id}/invites`, { userId: 'mem' });

  assert.equal((await inbox('mem'))[0].title, '프로젝트 초대');
  assert.match(telegram[0].text, /팀장#1111님이 "신제품"방에 초대했어요/);
  assert.equal(telegram[0].reply_markup.inline_keyboard[0][0].url, `https://app.test/?open=project:${room.id}`);

  const list = (await call('mem', 'GET', '/api/project-rooms')).body;
  assert.deepEqual([list.total, list.invites[0].roomName, list.invites[0].invitedBy], [0, '신제품', '팀장#1111']);
  assert.equal((await call('mem', 'GET', `/api/project-rooms/${room.id}`)).body.me.status, 'invited');
  assert.equal((await call('mem', 'POST', `/api/project-rooms/${room.id}/projects`, { name: 'x' })).status, 404, '수락 전');

  await call('mem', 'POST', `/api/project-rooms/${room.id}/accept`);
  assert.equal((await call('mem', 'GET', '/api/project-rooms')).body.rooms[0].name, '신제품');
  assert.equal((await call('out', 'GET', `/api/project-rooms/${room.id}`)).status, 404, '모르는 사람은 볼 수 없다');
});

test('팀장만 방·프로젝트·세부업무를 바꿀 수 있고, 담당자는 팀원 중에서만 고른다', async () => {
  const { roomId, projectId } = await roomWithMember();
  assert.equal((await call('mem', 'PUT', `/api/project-rooms/${roomId}`, { name: 'x' })).status, 403);
  assert.equal((await call('mem', 'POST', `/api/projects/${projectId}/tasks`, { title: 'x' })).status, 403);
  assert.equal((await call('mem', 'POST', `/api/project-rooms/${roomId}/invites`, { userId: 'out' })).status, 403);
  assert.equal((await call('lead', 'POST', `/api/projects/${projectId}/tasks`, { title: 'x', assigneeId: 'out' })).status, 400);
});

test('배정·수정·재배정·삭제는 담당자에게, 완료 보고는 팀장에게 알린다', async () => {
  const { roomId, projectId } = await roomWithMember();
  let d = (await call('lead', 'POST', `/api/projects/${projectId}/tasks`, { title: '시안', assigneeId: 'mem', dueAt: 2e12 })).body;
  const taskId = d.projects[0].tasks[0].id;
  assert.deepEqual([(await inbox('mem'))[0].title, (await inbox('mem'))[0].body], ['업무 배정', '신제품방 - 시안']);

  await call('lead', 'PUT', `/api/project-tasks/${taskId}`, { title: '시안 v2' });
  assert.equal((await inbox('mem'))[0].title, '업무 수정');

  assert.equal((await call('lead', 'POST', `/api/project-tasks/${taskId}/complete`)).status, 403, '남의 업무');
  d = (await call('mem', 'POST', `/api/project-tasks/${taskId}/complete`)).body;
  assert.ok(d.projects[0].tasks[0].doneAt);
  const lead = await inbox('lead');
  assert.deepEqual([lead[0].title, lead[0].body], ['업무 완료 보고', '팀원#2222님이 신제품방 - 시안 v2 완료를 보고했어요']);
  const list = (await call('lead', 'GET', '/api/project-rooms')).body.rooms[0];
  assert.deepEqual([list.done, list.total, list.members], [1, 1, 2]);

  d = (await call('lead', 'POST', `/api/projects/${projectId}/tasks`, { title: '문구', assigneeId: 'mem' })).body;
  const t2 = d.projects[0].tasks[1].id;
  await call('lead', 'PUT', `/api/project-tasks/${t2}`, { assigneeId: 'lead' });
  assert.equal((await inbox('mem'))[0].title, '업무 배정 취소');
  assert.equal((await inbox('lead')).filter((n) => n.title === '업무 배정').length, 0, '본인에게는 알리지 않는다');
  await call('lead', 'PUT', `/api/project-tasks/${t2}`, { assigneeId: 'mem' });
  await call('lead', 'DELETE', `/api/project-tasks/${t2}`);
  assert.equal((await inbox('mem'))[0].title, '업무 삭제');
});

test('팀원을 내보내면 그 사람의 진행 중인 업무는 담당자 없음이 된다', async () => {
  const { roomId, projectId } = await roomWithMember();
  await call('lead', 'POST', `/api/projects/${projectId}/tasks`, { title: '시안', assigneeId: 'mem' });
  const d = (await call('lead', 'DELETE', `/api/project-rooms/${roomId}/members/mem`)).body;
  assert.deepEqual([d.members.length, d.projects[0].tasks[0].assigneeId], [1, null]);
  assert.equal((await call('mem', 'GET', `/api/project-rooms/${roomId}`)).status, 404);
});

test('방 목록은 10개씩 나눠 보여준다', async () => {
  for (let i = 0; i < 12; i++) await call('lead', 'POST', '/api/project-rooms', { name: `방 ${i}` });
  const p1 = (await call('lead', 'GET', '/api/project-rooms?page=1')).body;
  const p2 = (await call('lead', 'GET', '/api/project-rooms?page=2')).body;
  assert.deepEqual([p1.total, p1.rooms.length, p2.rooms.length], [12, 10, 2]);
});
