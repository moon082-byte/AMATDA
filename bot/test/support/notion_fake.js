// 노션 연동 테스트 공용: 가짜 노션 API(fetch)와 로그인한 사용자 한 명
import { sha256Hex } from '../../src/crypto.js';
import worker from '../../src/index.js';
import { fakeD1 } from './d1.js';

export const TOKEN = 'tok_u1'.padEnd(40, 'x');
export const NOTION_TOKEN = 'ntn_test_secret_1234567890abcdef';
export const TASK_DB = '1111ece31bb580509babd28537b58808';
export const MEMO_DB = '3955ece31bb580509babd28537b58808';

/** 노션 데이터베이스 모양 (테스트에서 바꿔 볼 수 있다) */
export const schemas = () => ({
  [TASK_DB]: {
    title: [{ plain_text: '할 일 목록' }],
    properties: {
      작업: { type: 'title' }, 끝남: { type: 'checkbox' }, 마감: { type: 'date' }, 메모: { type: 'rich_text' },
      진행: { type: 'status', status: { options: [{ name: '시작 전' }, { name: '진행 중' }, { name: '완료' }] } },
    },
  },
  [MEMO_DB]: {
    title: [{ plain_text: '받은 메모' }],
    properties: {
      이름: { type: 'title' }, 내용: { type: 'rich_text' }, 생성일: { type: 'created_time' }, 작성: { type: 'date' },
      상태: { type: 'select', select: { options: [{ name: '정리 대기' }, { name: '정리 완료' }] } },
    },
  },
});

/** 테스트 하나의 환경: { env, calls, call(), sync(), state } */
export async function setup() {
  const env = { DB: fakeD1(), BOT_TOKEN: '123:test', ALLOWED_EMAILS: 'a@x.com' };
  env.DB.exec(`INSERT INTO users (id, google_sub, email, created_at) VALUES ('u1', 'g1', 'a@x.com', 0);
    INSERT INTO sessions (token_hash, user_id, created_at, last_used_at)
      VALUES ('${await sha256Hex(TOKEN)}', 'u1', ${Date.now()}, ${Date.now()});`);
  const state = { calls: [], down: false, dbs: schemas(), children: [{ id: 'blk1' }] };
  globalThis.fetch = async (url, init) => {
    const u = new URL(String(url));
    const path = u.pathname.replace('/v1', '');
    const body = init.body ? JSON.parse(init.body) : null;
    state.calls.push({ method: init.method, path, body, auth: init.headers.Authorization });
    const ok = (j) => new Response(JSON.stringify(j), { status: 200 });
    if (state.down) return new Response('{"message":"잠시 후 다시"}', { status: 503 });
    const db = /^\/databases\/(\w+)$/.exec(path);
    if (db) return state.dbs[db[1]] ? ok(state.dbs[db[1]]) : new Response('{"message":"없음"}', { status: 404 });
    if (init.method === 'POST' && path === '/pages') return ok({ id: `page-${state.calls.length}` });
    if (init.method === 'GET' && path.includes('/children')) return ok({ results: state.children });
    return ok({});
  };
  const call = async (method, p, b) => {
    const pending = [];
    const res = await worker.fetch(new Request(`https://bot.test${p}`, {
      method, headers: { Authorization: `Bearer ${TOKEN}` }, body: b ? JSON.stringify(b) : undefined,
    }), env, { waitUntil: (x) => pending.push(x) });
    await Promise.all(pending);
    return { status: res.status, body: await res.json() };
  };
  const sync = (changes) => call('POST', '/api/sync', { since: 0, device: 'dev_aaaaaaaa', changes });
  const row = (table, id) => env.DB.rows(`SELECT * FROM ${table} WHERE id = '${id}'`)[0];
  return { env, state, call, sync, row };
}

export const record = (id, data, { parentId = null, deleted = false, position = 0 } = {}) =>
  ({ id, parentId, position, deleted, data: JSON.stringify(data) });

export const TASK_MAP = { title: '작업', done: { prop: '끝남' }, date: '마감', content: '메모' };
export const MEMO_MAP = { title: '이름', content: '내용', date: '작성', status: { prop: '상태', value: '정리 대기' } };
