import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { afterEach, beforeEach, test } from 'node:test';
import { notionId } from '../src/notion.js';
import { syncNotion } from '../src/notion_push.js';
import { MEMO_DB, MEMO_MAP, NOTION_TOKEN, TASK_DB, TASK_MAP, record, setup } from './support/notion_fake.js';

const realFetch = globalThis.fetch;
let t;
beforeEach(async () => { t = await setup(); });
afterEach(() => { globalThis.fetch = realFetch; });

const info = (id) => JSON.parse(t.row('memos', id).data).notion;
const enableMemos = (map = MEMO_MAP) =>
  t.call('PUT', '/api/notion', { enabled: true, token: NOTION_TOKEN, memoDb: `https://www.notion.so/x/메모-${MEMO_DB}?v=abc`, memoMap: map });

test('DB 링크를 붙여 넣으면 속성 목록을 읽어 매핑 드롭다운에 쓸 수 있다', async () => {
  assert.equal(notionId(`https://app.notion.com/p/${TASK_DB}?pvs=204`), TASK_DB);
  const res = await t.call('POST', '/api/notion/inspect', { token: NOTION_TOKEN, db: `https://notion.so/할일-${TASK_DB}` });
  assert.equal(res.status, 200);
  assert.equal(res.body.id, TASK_DB);
  assert.equal(res.body.name, '할 일 목록');
  assert.deepEqual(res.body.properties.find((p) => p.name === '진행'), { name: '진행', type: 'status', options: ['시작 전', '진행 중', '완료'] });
  const missing = await t.call('POST', '/api/notion/inspect', { token: NOTION_TOKEN, db: 'ffffffffffffffffffffffffffffffff' });
  assert.equal(missing.status, 400);
  assert.match(missing.body.error, /\[연결\]에 통합을 추가/);
});

test('설정 저장: 토큰은 암호화하고 앱에 돌려주지 않는다, 할일·메모 DB와 매핑을 각각 저장', async () => {
  const res = await t.call('PUT', '/api/notion', {
    enabled: true, token: NOTION_TOKEN, taskDb: TASK_DB, taskMap: TASK_MAP, memoDb: MEMO_DB, memoMap: MEMO_MAP,
  });
  assert.equal(res.status, 200);
  assert.equal(res.body.hasToken, true);
  assert.equal(JSON.stringify(res.body).includes(NOTION_TOKEN), false);
  assert.deepEqual(res.body.taskMap, { title: '작업', done: { prop: '끝남', type: 'checkbox' }, date: '마감', content: '메모' });
  assert.deepEqual(res.body.memoMap.status, { prop: '상태', type: 'select', value: '정리 대기' });
  assert.ok(!t.env.DB.rows('SELECT notion_token FROM users')[0].notion_token.includes(NOTION_TOKEN));
  // 메모 DB만 끊기 ('' = 연결 해제)
  const off = await t.call('PUT', '/api/notion', { memoDb: '' });
  assert.deepEqual([off.body.enabled, off.body.taskDb, off.body.memoDb, off.body.memoMap], [true, TASK_DB, null, null]);
});

test('매핑이 DB 속성과 맞지 않으면 이유를 알려 주고 저장하지 않는다', async () => {
  const bad = async (map, pattern) => {
    const res = await t.call('PUT', '/api/notion', { enabled: true, token: NOTION_TOKEN, taskDb: TASK_DB, taskMap: map });
    assert.equal(res.status, 400);
    assert.match(res.body.error, pattern);
  };
  await bad({ done: { prop: '끝남' } }, /제목으로 쓸 속성/);
  await bad({ title: '마감' }, /제목에는 '마감' 속성\(date\)을 쓸 수 없어요/);
  await bad({ title: '작업', date: '없는칸' }, /'없는칸' 속성을 데이터베이스에서 찾을 수 없어요/);
  await bad({ title: '작업', done: { prop: '진행', doneValue: '끝', todoValue: '시작 전' } }, /'진행'에 '끝' 값이 없어요/);
  const none = await t.call('PUT', '/api/notion', { enabled: true, token: NOTION_TOKEN });
  assert.match(none.body.error, /데이터베이스를 하나 이상/);
  assert.equal((await t.call('GET', '/api/notion')).body.enabled, false);
});

test('메모: 고른 매핑대로 생성(처음 상태는 새로 만들 때만), 수정 → 갱신, 삭제 → 휴지통', async () => {
  await enableMemos();
  t.state.calls = [];
  const long = '가'.repeat(250);
  await t.sync({ memos: [record('m1', { title: '아이디어', content: long, createdAt: '2026-11-25T09:30:00.000', updatedAt: 'v1' })] });
  const create = t.state.calls.find((c) => c.method === 'POST' && c.path === '/pages');
  assert.equal(create.auth, `Bearer ${NOTION_TOKEN}`);
  assert.equal(create.body.parent.database_id, MEMO_DB);
  assert.equal(create.body.properties.이름.title[0].text.content, '아이디어');
  assert.equal(create.body.properties.내용.rich_text[0].text.content.length, 200);
  assert.deepEqual(create.body.properties.작성, { date: { start: '2026-11-25T09:30:00+09:00' } });
  assert.deepEqual(create.body.properties.상태, { select: { name: '정리 대기' } });
  assert.equal(create.body.children[0].paragraph.rich_text[0].text.content, long);
  const pageId = t.row('memos', 'm1').notion_page_id;
  assert.deepEqual(info('m1'), { pageId, syncedFor: 'v1', error: null });

  t.state.calls = [];
  await t.sync({ memos: [record('m1', { title: '아이디어 2', content: '짧게', updatedAt: 'v2' })] });
  const patch = t.state.calls.find((c) => c.method === 'PATCH' && c.path === `/pages/${pageId}`);
  assert.equal(patch.body.properties.상태, undefined, '노션에서 바꾼 상태는 덮어쓰지 않는다');
  assert.ok(t.state.calls.some((c) => c.method === 'PATCH' && c.path === `/blocks/${pageId}/children`));

  t.state.calls = [];
  await t.sync({ memos: [record('m1', { title: '아이디어 2', content: '짧게', updatedAt: 'v2' }, { deleted: true })] });
  assert.deepEqual(t.state.calls.map((c) => [c.method, c.path, c.body]), [['PATCH', `/pages/${pageId}`, { archived: true }]]);
});

test('노션이 실패하면 오류를 남기고 다시 시도한다, 설정 화면에 실패 개수와 이유가 보인다, 끄면 보내지 않는다', async () => {
  await enableMemos();
  t.state.down = true;
  await t.sync({ memos: [record('m2', { title: '실패', content: '', updatedAt: 'v1' })] });
  assert.match(info('m2').error, /잠시 후/);
  const view = (await t.call('GET', '/api/notion')).body;
  assert.deepEqual([view.waiting, view.failed], [1, 1]);
  assert.match(view.lastError, /잠시 후/);
  t.state.down = false;
  await syncNotion(t.env);
  assert.equal(info('m2').error, null);
  assert.equal(t.row('memos', 'm2').notion_dirty, 0);

  await t.call('PUT', '/api/notion', { enabled: false });
  t.state.calls = [];
  await t.sync({ memos: [record('m3', { title: '끔', content: '', updatedAt: 'v1' })] });
  await syncNotion(t.env);
  assert.equal(t.state.calls.length, 0);
});

test('예전 메모 연동 설정(이름·내용·상태=정리 대기)은 새 매핑으로 그대로 옮긴다', async () => {
  t.env.DB.exec(`UPDATE users SET notion_memo_db = '${MEMO_DB}', notion_status_type = 'status', notion_memo_map = NULL`);
  const sql = readFileSync(new URL('../migrations/0015_notion_tasks.sql', import.meta.url), 'utf8');
  t.env.DB.exec(/UPDATE users SET notion_memo_map[\s\S]*?;/.exec(sql)[0]);
  assert.deepEqual(JSON.parse(t.env.DB.rows('SELECT notion_memo_map FROM users')[0].notion_memo_map),
    { title: '이름', content: '내용', status: { prop: '상태', type: 'status', value: '정리 대기' } });
});
