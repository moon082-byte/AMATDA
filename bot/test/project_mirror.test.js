import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';
import { sha256Hex } from '../src/crypto.js';
import worker from '../src/index.js';
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
/** 그 사람의 개인 할일(동기화 데이터)에 있는 프로젝트 업무 */
const mirror = (userId, taskId) => {
  const row = env.DB.rows(`SELECT * FROM tasks WHERE user_id = '${userId}' AND id = 'pt_${taskId}'`)[0];
  return row && { ...row, data: JSON.parse(row.data) };
};
const upload = (id, row) => call(id, 'POST', '/api/sync', {
  since: 0, device: 'device_mmmmmmmm', changes: { tasks: [{ position: 0, parentId: null, deleted: false, ...row }] },
});

/** 팀장(lead)이 방·프로젝트를 만들고 팀원(mem)에게 업무 하나를 배정한 상태 */
async function assigned() {
  const room = (await call('lead', 'POST', '/api/project-rooms', { name: '신제품' })).body.room;
  await call('lead', 'POST', `/api/project-rooms/${room.id}/invites`, { userId: 'mem' });
  await call('mem', 'POST', `/api/project-rooms/${room.id}/accept`);
  const p = (await call('lead', 'POST', `/api/project-rooms/${room.id}/projects`, { name: '디자인' })).body.projects[0];
  const d = (await call('lead', 'POST', `/api/projects/${p.id}/tasks`,
    { title: '시안', assigneeId: 'mem', dueAt: Date.UTC(2026, 10, 20, 9) })).body;
  return { roomId: room.id, projectId: p.id, taskId: d.projects[0].tasks[0].id };
}

beforeEach(async () => {
  env = { DB: fakeD1(), ALLOWED_EMAILS: 'lead@x.com,mem@x.com,out@x.com' };
  await addUser('lead', '팀장', '1111');
  await addUser('mem', '팀원', '2222');
  await addUser('out', '외부', '3333');
  globalThis.fetch = async () => new Response('{}', { status: 200 });
});
afterEach(() => {
  globalThis.fetch = realFetch;
});

test('배정하면 담당자 개인 할일에 프로젝트 이름과 함께 들어가고, 다음 동기화 때 받는다', async () => {
  const { roomId, taskId } = await assigned();
  const m = mirror('mem', taskId);
  assert.deepEqual([m.data.title, m.data.dueDate, m.data.isDone], ['시안', '2026-11-20T09:00:00.000Z', false]);
  assert.deepEqual(m.data.project,
    { roomId, roomName: '신제품', projectName: '디자인', taskId, reviewRequested: false });
  const pulled = (await call('mem', 'POST', '/api/sync', { since: 0, changes: {} })).body.changes.tasks;
  assert.ok(pulled.some((r) => r.id === `pt_${taskId}`));
});

test('개인 할일에서는 업무방 태그·리마인더만 바뀌고, 제목·마감은 프로젝트 값으로 되돌린다', async () => {
  const { roomId, taskId } = await assigned();
  const data = { ...mirror('mem', taskId).data, title: '몰래 바꿈', dueDate: null, remindAt: ['2026-11-20T08:00:00.000'] };
  await upload('mem', { id: `pt_${taskId}`, parentId: 'room_mine', data: JSON.stringify(data) });
  let m = mirror('mem', taskId);
  assert.deepEqual([m.data.title, m.data.dueDate, m.parent_id, m.data.remindAt],
    ['시안', '2026-11-20T09:00:00.000Z', 'room_mine', ['2026-11-20T08:00:00.000']]);

  // 팀장이 고치면 잠긴 칸만 바뀌고 담당자 설정은 남는다
  await call('lead', 'PUT', `/api/project-tasks/${taskId}`, { title: '시안 v2' });
  await call('lead', 'PUT', `/api/project-rooms/${roomId}`, { name: '신제품 2' });
  m = mirror('mem', taskId);
  assert.deepEqual([m.data.title, m.data.project.roomName, m.parent_id, m.data.remindAt.length],
    ['시안 v2', '신제품 2', 'room_mine', 1]);
});

const review = (taskId, on) => {
  const data = mirror('mem', taskId).data;
  return JSON.stringify({ ...data, project: { ...data.project, reviewRequested: on } });
};
const task0 = async (roomId) => (await call('lead', 'GET', `/api/project-rooms/${roomId}`)).body.projects[0].tasks[0];
const inboxOf = async (id) => (await call(id, 'GET', '/api/notifications?device=dev_llllllll')).body.items;

test('개인 할일에서 체크하면 검토 요청(검토중)이 되고, 다시 체크하면 취소된다', async () => {
  const { roomId, taskId } = await assigned();
  await upload('mem', { id: `pt_${taskId}`, data: review(taskId, true) });
  let t = await task0(roomId);
  assert.deepEqual([!!t.reviewAt, t.doneAt], [true, null], '완료가 아니라 검토중');
  assert.equal((await inboxOf('lead'))[0].title, '검토 요청');
  assert.deepEqual([mirror('mem', taskId).data.isDone, mirror('mem', taskId).data.project.reviewRequested], [false, true]);

  await upload('mem', { id: `pt_${taskId}`, data: review(taskId, false) });
  t = await task0(roomId);
  assert.equal(t.reviewAt, null, '검토 요청 취소 → 진행중');

  // 예전 앱처럼 isDone으로 체크해 올려도 검토 요청으로 처리한다
  await upload('mem', { id: `pt_${taskId}`, data: JSON.stringify({ ...mirror('mem', taskId).data, isDone: true }) });
  assert.ok((await task0(roomId)).reviewAt);
});

test('팀장이 최종완료하면 담당자 개인 할일에서 사라지고, 반려하면 진행중으로 돌아간다', async () => {
  const { roomId, taskId } = await assigned();
  await call('mem', 'POST', `/api/project-tasks/${taskId}/complete`);
  assert.equal((await call('mem', 'POST', `/api/project-tasks/${taskId}/approve`)).status, 403, '팀원은 최종완료 불가');

  await call('lead', 'POST', `/api/project-tasks/${taskId}/reject`);
  assert.equal((await task0(roomId)).reviewAt, null);
  assert.deepEqual([(await inboxOf('mem'))[0].title, mirror('mem', taskId).deleted], ['반려', 0]);
  assert.equal((await call('lead', 'POST', `/api/project-tasks/${taskId}/approve`)).status, 409, '검토 요청 전');

  await call('mem', 'POST', `/api/project-tasks/${taskId}/complete`);
  await call('lead', 'POST', `/api/project-tasks/${taskId}/approve`);
  assert.ok((await task0(roomId)).doneAt);
  assert.deepEqual([(await inboxOf('mem'))[0].title, mirror('mem', taskId).deleted], ['최종완료', 1]);
});

test('팀장 본인 업무는 [완료]하면 바로 최종완료된다', async () => {
  const { roomId, projectId } = await assigned();
  const d = (await call('lead', 'POST', `/api/projects/${projectId}/tasks`, { title: '내 업무', assigneeId: 'lead' })).body;
  const mine = d.projects[0].tasks.find((t) => t.title === '내 업무');
  await call('lead', 'POST', `/api/project-tasks/${mine.id}/complete`);
  const after = (await call('lead', 'GET', `/api/project-rooms/${roomId}`)).body.projects[0].tasks.find((t) => t.id === mine.id);
  assert.ok(after.doneAt);
  assert.equal(mirror('lead', mine.id).deleted, 1);
});

test('진행 중 업무는 개인 할일에서 지워도 다시 내려오고, 남의 업무는 올려도 무시한다', async () => {
  const { taskId } = await assigned();
  const before = mirror('mem', taskId).version;
  await upload('mem', { id: `pt_${taskId}`, deleted: true, data: '{}' });
  const after = mirror('mem', taskId);
  assert.equal(after.deleted, 0);
  assert.ok(after.version > before, '다음 동기화 때 다시 받도록 순번을 올린다');

  await upload('out', { id: `pt_${taskId}`, data: JSON.stringify({ title: 'x', isDone: true }) });
  assert.equal(mirror('out', taskId), undefined);
});

test('재배정·업무 삭제·프로젝트 삭제·내보내기 하면 개인 할일에서 사라진다', async () => {
  const { roomId, projectId, taskId } = await assigned();
  await call('lead', 'PUT', `/api/project-tasks/${taskId}`, { assigneeId: 'lead' });
  assert.equal(mirror('mem', taskId).deleted, 1);
  assert.equal(mirror('lead', taskId).deleted, 0);
  await call('lead', 'DELETE', `/api/project-tasks/${taskId}`);
  assert.equal(mirror('lead', taskId).deleted, 1);

  const t2 = (await call('lead', 'POST', `/api/projects/${projectId}/tasks`, { title: '문구', assigneeId: 'mem' }))
    .body.projects[0].tasks[0].id;
  await call('lead', 'DELETE', `/api/project-rooms/${roomId}/members/mem`);
  assert.equal(mirror('mem', t2).deleted, 1);

  const t3 = (await call('lead', 'POST', `/api/projects/${projectId}/tasks`, { title: '사진', assigneeId: 'lead' }))
    .body.projects[0].tasks.find((t) => t.title === '사진').id;
  await call('lead', 'DELETE', `/api/projects/${projectId}`);
  assert.equal(mirror('lead', t3).deleted, 1);
});
