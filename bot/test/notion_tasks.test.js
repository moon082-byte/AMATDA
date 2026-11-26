import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';
import { syncNotion } from '../src/notion_push.js';
import { NOTION_TOKEN, TASK_DB, TASK_MAP, record, setup } from './support/notion_fake.js';

const realFetch = globalThis.fetch;
let t;
beforeEach(async () => { t = await setup(); });
afterEach(() => { globalThis.fetch = realFetch; });

const enable = (map = TASK_MAP) => t.call('PUT', '/api/notion', { enabled: true, token: NOTION_TOKEN, taskDb: TASK_DB, taskMap: map });
const task = (id, data, opts) => record(id, { title: id, isDone: false, ...data }, opts);
const creates = () => t.state.calls.filter((c) => c.method === 'POST' && c.path === '/pages');

test('할 일: 제목·완료·마감·내용으로 생성, 본문은 설명 → 세부 체크리스트 → 메모', async () => {
  await enable();
  t.state.calls = [];
  await t.sync({
    tasks: [task('t1', { title: '보고서', description: '3쪽 분량', dueDate: '2026-11-27T00:00:00.000' }, { parentId: 'room1' })],
    sub_tasks: [record('s1', { title: '표 넣기', isDone: true }, { parentId: 't1' })],
    notes: [record('n1', { content: '팀장님 확인' }, { parentId: 't1' })],
  });
  const [create] = creates();
  assert.equal(create.body.parent.database_id, TASK_DB);
  const p = create.body.properties;
  assert.equal(p.작업.title[0].text.content, '보고서');
  assert.deepEqual(p.끝남, { checkbox: false });
  assert.deepEqual(p.마감, { date: { start: '2026-11-27' } }, '날짜만 정한 마감은 날짜로');
  assert.equal(p.메모.rich_text[0].text.content, '3쪽 분량\n팀장님 확인');
  assert.deepEqual(create.body.children.map((b) => b.type), ['paragraph', 'to_do', 'paragraph']);
  assert.equal(create.body.children[1].to_do.checked, true);
  assert.equal(t.row('tasks', 't1').notion_dirty, 0);

  // 완료만 바꾸면 속성만 고친다 (본문은 그대로라 다시 쓰지 않는다)
  const pageId = t.row('tasks', 't1').notion_page_id;
  t.state.calls = [];
  await t.sync({ tasks: [task('t1', { title: '보고서', description: '3쪽 분량', isDone: true, dueDate: '2026-11-27T15:00:00.000' }, { parentId: 'room1' })] });
  assert.deepEqual(t.state.calls.map((c) => [c.method, c.path]), [['PATCH', `/pages/${pageId}`]]);
  assert.deepEqual(t.state.calls[0].body.properties.끝남, { checkbox: true });
  assert.deepEqual(t.state.calls[0].body.properties.마감, { date: { start: '2026-11-27T15:00:00+09:00' } });

  // 세부 항목을 추가하면 본문도 다시 쓴다
  t.state.calls = [];
  await t.sync({ sub_tasks: [record('s2', { title: '요약', isDone: false }, { parentId: 't1', position: 1 })] });
  assert.ok(t.state.calls.some((c) => c.method === 'DELETE' && c.path === '/blocks/blk1'));
  const append = t.state.calls.find((c) => c.path === `/blocks/${pageId}/children` && c.method === 'PATCH');
  assert.deepEqual(append.body.children.filter((b) => b.type === 'to_do').map((b) => b.to_do.rich_text[0].text.content), ['표 넣기', '요약']);

  t.state.calls = [];
  await t.sync({ tasks: [task('t1', {}, { deleted: true, parentId: 'room1' })] });
  assert.deepEqual(t.state.calls.map((c) => [c.method, c.body]), [['PATCH', { archived: true }]]);
});

test('완료를 상태 속성으로 매핑하면 고른 "완료 값"과 "할 일 값"을 쓴다', async () => {
  const res = await enable({ title: '작업', done: { prop: '진행', doneValue: '완료', todoValue: '시작 전' } });
  assert.deepEqual(res.body.taskMap.done, { prop: '진행', type: 'status', doneValue: '완료', todoValue: '시작 전' });
  t.state.calls = [];
  await t.sync({ tasks: [task('a', {}), task('b', { isDone: true })] });
  assert.deepEqual(creates().map((c) => c.body.properties.진행), [{ status: { name: '시작 전' } }, { status: { name: '완료' } }]);
  assert.equal(creates()[0].body.properties.마감, undefined, '매핑하지 않은 속성은 보내지 않는다');
});

test('연결 전에 있던 할 일은 자동으로 보내지 않고, [기존 항목 보내기]로 한 번에 보낸다', async () => {
  await t.sync({ tasks: [task('old1', {}), task('old2', {}), task('gone', {}, { deleted: true })] });
  t.state.calls = [];
  await enable();
  assert.equal(creates().length, 0);
  const res = await t.call('POST', '/api/notion/backfill', { target: 'tasks' });
  assert.equal(res.body.count, 2, '지운 할 일은 빼고');
  assert.equal(creates().length, 2);
  assert.equal((await t.call('POST', '/api/notion/backfill', { target: 'tasks' })).body.count, 0, '이미 보낸 것은 다시 안 보낸다');
});

test('한 번에 노션을 너무 많이 부르지 않고, 남은 것은 다음 차례에 이어서 보낸다', async () => {
  await t.sync({ tasks: Array.from({ length: 45 }, (_, i) => task(`bulk${i}`, {})) });
  await enable();
  t.state.calls = [];
  await t.call('POST', '/api/notion/backfill', { target: 'tasks' });
  assert.equal(creates().length, 40);
  await syncNotion(t.env);
  assert.equal(creates().length, 45);
});

test('다른 데이터베이스로 바꾸면 예전 페이지 연결을 끊는다 (다음 반영 때 새 DB에 만든다)', async () => {
  await enable();
  await t.sync({ tasks: [task('t9', {})] });
  assert.ok(t.row('tasks', 't9').notion_page_id);
  t.state.dbs.ffffeeeeddddccccbbbbaaaa99998888 = t.state.dbs[TASK_DB];
  await t.call('PUT', '/api/notion', { taskDb: 'ffffeeeeddddccccbbbbaaaa99998888', taskMap: TASK_MAP });
  assert.equal(t.row('tasks', 't9').notion_page_id, null);
});
