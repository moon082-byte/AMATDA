import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';
import { sha256Hex } from '../src/crypto.js';
import worker from '../src/index.js';
import { notionId } from '../src/notion.js';
import { syncNotionMemos } from '../src/notion_memos.js';
import { fakeD1 } from './support/d1.js';

let env;
let notionCalls;
let notionDown;
const realFetch = globalThis.fetch;
const TOKEN = 'tok_u1'.padEnd(40, 'x');
const NOTION_TOKEN = 'ntn_test_secret_1234567890abcdef';
const DB = '3955ece31bb580509babd28537b58808';
const SCHEMA = { properties: { 이름: { type: 'title' }, 내용: { type: 'rich_text' }, 상태: { type: 'select' }, 생성일: { type: 'created_time' } } };

async function call(method, path, body) {
  const pending = [];
  const res = await worker.fetch(new Request(`https://bot.test${path}`, {
    method, headers: { Authorization: `Bearer ${TOKEN}` }, body: body ? JSON.stringify(body) : undefined,
  }), env, { waitUntil: (p) => pending.push(p) });
  await Promise.all(pending);
  return { status: res.status, body: await res.json() };
}
const memo = (id, data, deleted = false) => ({ id, parentId: null, position: 0, deleted, data: JSON.stringify(data) });
const sync = (memos) => call('POST', '/api/sync', { since: 0, device: 'dev_aaaaaaaa', changes: { memos } });
const row = (id) => env.DB.rows(`SELECT * FROM memos WHERE id = '${id}'`)[0];
const info = (id) => JSON.parse(row(id).data).notion;

beforeEach(async () => {
  env = { DB: fakeD1(), BOT_TOKEN: '123:test', ALLOWED_EMAILS: 'a@x.com' };
  env.DB.exec(`INSERT INTO users (id, google_sub, email, created_at) VALUES ('u1', 'g1', 'a@x.com', 0);
    INSERT INTO sessions (token_hash, user_id, created_at, last_used_at)
      VALUES ('${await sha256Hex(TOKEN)}', 'u1', ${Date.now()}, ${Date.now()});`);
  notionCalls = [];
  notionDown = false;
  globalThis.fetch = async (url, init) => {
    const u = new URL(String(url));
    const body = init.body ? JSON.parse(init.body) : null;
    notionCalls.push({ method: init.method, path: u.pathname.replace('/v1', ''), body, auth: init.headers.Authorization });
    const ok = (j) => new Response(JSON.stringify(j), { status: 200 });
    if (notionDown) return new Response('{"message":"잠시 후"}', { status: 503 });
    if (u.pathname === `/v1/databases/${DB}`) return ok(SCHEMA);
    if (init.method === 'POST' && u.pathname === '/v1/pages') return ok({ id: `page-${notionCalls.length}` });
    if (init.method === 'GET' && u.pathname.endsWith('/children')) return ok({ results: [{ id: 'blk1' }] });
    return ok({});
  };
});
afterEach(() => {
  globalThis.fetch = realFetch;
});

const enable = () => call('PUT', '/api/notion', { enabled: true, token: NOTION_TOKEN, memoDb: `https://www.notion.so/x/1_Inbox-${DB}?v=abc` });

test('노션 설정: DB 주소를 붙여넣어도 id로 저장, 토큰은 암호화하고 앱에 돌려주지 않는다', async () => {
  assert.equal(notionId(`https://app.notion.com/p/${DB}?pvs=204`), DB);
  const res = await enable();
  assert.equal(res.status, 200);
  assert.deepEqual(res.body, { enabled: true, hasToken: true, memoDb: DB });
  const u = env.DB.rows("SELECT notion_token, notion_status_type FROM users")[0];
  assert.ok(!u.notion_token.includes(NOTION_TOKEN), '토큰을 그대로 저장하지 않는다');
  assert.equal(u.notion_status_type, 'select');
  assert.deepEqual((await call('GET', '/api/notion')).body, { enabled: true, hasToken: true, memoDb: DB });
  assert.equal((await call('POST', '/api/notion/check', {})).body.ok, true, '저장된 값으로 연결 확인');
});

test('필요한 속성이 없는 DB는 켤 수 없다', async () => {
  SCHEMA.properties.상태.type = 'number';
  try {
    const res = await enable();
    assert.equal(res.status, 400);
    assert.match(res.body.error, /상태\(선택\)/);
  } finally {
    SCHEMA.properties.상태.type = 'select';
  }
});

test('메모 저장 → 노션 1_Inbox에 생성(이름·내용 요약·상태=정리 대기·본문 전체), 수정 → 갱신(상태는 그대로), 삭제 → 휴지통', async () => {
  await enable();
  notionCalls = [];
  const long = '가'.repeat(250);
  await sync([memo('memo_1', { title: '아이디어', content: long, updatedAt: 'v1' })]);
  const create = notionCalls.find((c) => c.method === 'POST' && c.path === '/pages');
  assert.equal(create.auth, `Bearer ${NOTION_TOKEN}`);
  assert.equal(create.body.parent.database_id, DB);
  assert.equal(create.body.properties.이름.title[0].text.content, '아이디어');
  assert.equal(create.body.properties.내용.rich_text[0].text.content.length, 200);
  assert.deepEqual(create.body.properties.상태, { select: { name: '정리 대기' } });
  assert.equal(create.body.children[0].paragraph.rich_text[0].text.content, long);
  const pageId = row('memo_1').notion_page_id;
  assert.ok(pageId);
  assert.deepEqual(info('memo_1'), { pageId, syncedFor: 'v1', error: null });
  assert.equal(row('memo_1').notion_dirty, 0);

  notionCalls = [];
  await sync([memo('memo_1', { title: '아이디어 2', content: '짧게', updatedAt: 'v2' })]);
  const patch = notionCalls.find((c) => c.method === 'PATCH' && c.path === `/pages/${pageId}`);
  assert.equal(patch.body.properties.이름.title[0].text.content, '아이디어 2');
  assert.equal(patch.body.properties.상태, undefined, '노션에서 바꾼 상태는 덮어쓰지 않는다');
  assert.ok(notionCalls.some((c) => c.method === 'DELETE' && c.path === '/blocks/blk1'));
  assert.ok(notionCalls.some((c) => c.method === 'PATCH' && c.path === `/blocks/${pageId}/children`));
  assert.equal(notionCalls.filter((c) => c.method === 'POST').length, 0, '새로 만들지 않는다');

  notionCalls = [];
  await sync([memo('memo_1', { title: '아이디어 2', content: '짧게', updatedAt: 'v2' }, true)]);
  assert.deepEqual(notionCalls.map((c) => [c.method, c.path, c.body]), [['PATCH', `/pages/${pageId}`, { archived: true }]]);
});

test('노션이 실패하면 메모에 오류를 남기고 1분마다 다시 시도한다, 연동을 끄면 보내지 않는다', async () => {
  await enable();
  notionDown = true;
  await sync([memo('memo_2', { title: '실패', content: '', updatedAt: 'v1' })]);
  assert.match(info('memo_2').error, /잠시 후/);
  assert.equal(row('memo_2').notion_dirty, 1);
  notionDown = false;
  await syncNotionMemos(env);
  assert.equal(info('memo_2').error, null);
  assert.equal(row('memo_2').notion_dirty, 0);

  await call('PUT', '/api/notion', { enabled: false });
  notionCalls = [];
  await sync([memo('memo_3', { title: '끔', content: '', updatedAt: 'v1' })]);
  await syncNotionMemos(env);
  assert.equal(notionCalls.length, 0);
});
