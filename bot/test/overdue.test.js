import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';
import { sha256Hex } from '../src/crypto.js';
import { replaceReminders } from '../src/db.js';
import worker from '../src/index.js';
import { recordOverdueInbox, sendProjectOverdue } from '../src/project_overdue.js';
import { fakeD1 } from './support/d1.js';

let env;
const realFetch = globalThis.fetch;
const tokens = {};
const HOUR = 3600_000;

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
const inbox = async (id) =>
  (await call(id, 'GET', '/api/notifications?device=dev_xxxxxxxx')).body.items.map((n) => `${n.title}|${n.body}`);
const mirror = (userId, taskId) => {
  const row = env.DB.rows(`SELECT * FROM tasks WHERE user_id = '${userId}' AND id = 'pt_${taskId}'`)[0];
  return row && { ...row, data: JSON.parse(row.data) };
};

/** 팀장(lead)·팀원(mem), 마감이 1시간 지난 업무를 팀원에게 배정한 상태 */
async function overdueTask() {
  const room = (await call('lead', 'POST', '/api/project-rooms', { name: '신제품' })).body.room;
  await call('lead', 'POST', `/api/project-rooms/${room.id}/invites`, { userId: 'mem' });
  await call('mem', 'POST', `/api/project-rooms/${room.id}/accept`);
  const p = (await call('lead', 'POST', `/api/project-rooms/${room.id}/projects`, { name: '디자인' })).body.projects[0];
  const d = (await call('lead', 'POST', `/api/projects/${p.id}/tasks`,
    { title: '시안', assigneeId: 'mem', dueAt: Date.now() - HOUR })).body;
  return { roomId: room.id, projectId: p.id, taskId: d.projects[0].tasks[0].id };
}

beforeEach(async () => {
  env = { DB: fakeD1(), ALLOWED_EMAILS: 'lead@x.com,mem@x.com' };
  await addUser('lead', '팀장', '1111');
  await addUser('mem', '팀원', '2222');
  globalThis.fetch = async () => new Response('{}', { status: 200 });
});
afterEach(() => {
  globalThis.fetch = realFetch;
});

test('마감이 지난 세부업무는 팀장에게 한 번 알리고, 마감을 바꾸면 새 마감 기준으로 다시 알린다', async () => {
  const { taskId } = await overdueTask();
  await sendProjectOverdue(env);
  await sendProjectOverdue(env);
  const note = '기한 지남|신제품방 - 시안 (담당 팀원#2222)';
  assert.equal((await inbox('lead')).filter((n) => n === note).length, 1);
  assert.equal((await inbox('mem')).filter((n) => n.startsWith('기한 지남')).length, 0, '담당자는 개인 할일 알림으로');

  await call('lead', 'PUT', `/api/project-tasks/${taskId}`, { dueAt: Date.now() - 1000 });
  await sendProjectOverdue(env);
  assert.equal((await inbox('lead')).filter((n) => n === note).length, 2);
});

test('날짜만 정한 마감(한국 시간 00:00)은 그날이 끝나야 기한 지남으로 알린다', async (t) => {
  const { taskId } = await overdueTask();
  const kstMidnight = Math.floor((Date.now() + 9 * HOUR) / (24 * HOUR)) * 24 * HOUR - 9 * HOUR;
  const realNow = Date.now;
  Date.now = () => kstMidnight + HOUR; // 오늘 새벽 1시 (한국 시간)
  t.after(() => { Date.now = realNow; });
  await call('lead', 'PUT', `/api/project-tasks/${taskId}`, { dueAt: kstMidnight });
  await sendProjectOverdue(env);
  assert.equal((await inbox('lead')).filter((n) => n.startsWith('기한 지남')).length, 0, '오늘 날짜 마감은 아직');

  await call('lead', 'PUT', `/api/project-tasks/${taskId}`, { dueAt: kstMidnight - 24 * HOUR });
  await sendProjectOverdue(env);
  assert.equal((await inbox('lead')).filter((n) => n.startsWith('기한 지남')).length, 1, '어제 날짜 마감은 지남');
});

test('담당자가 개인 할일에서 [미완료 처리]하면 프로젝트에도 미완료로 남고, 팀장이 마감을 바꾸면 다시 진행중', async () => {
  const { roomId, taskId } = await overdueTask();
  const data = { ...mirror('mem', taskId).data, missedAt: new Date().toISOString() };
  await call('mem', 'POST', '/api/sync', {
    since: 0, device: 'device_mmmmmmmm',
    changes: { tasks: [{ id: `pt_${taskId}`, parentId: null, position: 0, deleted: false, data: JSON.stringify(data) }] },
  });
  let t = (await call('lead', 'GET', `/api/project-rooms/${roomId}`)).body.projects[0].tasks[0];
  assert.ok(t.missedAt);
  assert.equal(t.doneAt, null, '완료와 구분');
  assert.ok((await inbox('lead')).includes('미완료 처리|팀원#2222님이 신제품방 - 시안을(를) 미완료 처리했어요'));
  assert.ok(mirror('mem', taskId).data.missedAt);
  assert.equal((await call('mem', 'GET', '/api/project-rooms')).body.rooms[0].myOpen, 0);

  await sendProjectOverdue(env);
  assert.equal((await inbox('lead')).filter((n) => n.startsWith('기한 지남')).length, 0, '미완료 처리한 업무는 기한 알림 없음');

  await call('lead', 'PUT', `/api/project-tasks/${taskId}`, { dueAt: Date.now() + 24 * HOUR });
  t = (await call('lead', 'GET', `/api/project-rooms/${roomId}`)).body.projects[0].tasks[0];
  assert.equal(t.missedAt, null);
  assert.equal(mirror('mem', taskId).data.missedAt, null, '담당자 할일에도 다시 들어간다');
});

test('개인 할일의 기한 지남 알림은 텔레그램·푸시가 없어도 알림함에 한 번 남는다', async () => {
  await replaceReminders(env, 'mem', [{
    key: 'due:task_1:2026', fireAt: Date.now() - 1000, dueAt: Date.now() - 1000,
    text: '[기한 지남] 보고서\n[마감기한] 11월 2일 (월) 18:00',
    buttons: [{ text: '📱 앱에서 보기', url: 'https://app.test/?open=task:task_1' }],
  }]);
  await recordOverdueInbox(env);
  await recordOverdueInbox(env);
  const items = (await call('mem', 'GET', '/api/notifications?device=dev_xxxxxxxx')).body.items;
  assert.equal(items.length, 1);
  assert.deepEqual([items[0].title, items[0].target], ['⏰ 기한 지남 · 보고서', 'task:task_1']);
});
