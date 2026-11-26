// 노션 연동 설정 (토큰은 돌려주지 않는다)
// - GET    /api/notion           { enabled, hasToken, taskDb, taskMap, memoDb, memoMap, waiting, failed, lastError }
// - POST   /api/notion/inspect   { token?, db }  → { id, name, properties: [{name, type, options?}] } (매핑 드롭다운용)
// - PUT    /api/notion           { enabled?, token?, taskDb?, taskMap?, memoDb?, memoMap? } ('' DB는 연결 해제)
// - POST   /api/notion/backfill  { target: 'tasks'|'memos' } → { count } [기존 항목 보내기]
// - POST   /api/notion/check     예전 앱 호환: 저장된(또는 보낸) 값으로 연결 확인
// - DELETE /api/notion           연동 해제 (토큰·DB·매핑 지움, 이미 만든 노션 페이지는 그대로)

import { HttpError, readJson } from './http.js';
import { NotionError, checkMap, inspectDb, notionId, openToken, sealToken } from './notion.js';
import { markExisting, syncNotion } from './notion_push.js';

const TOKEN_PATTERN = /^[A-Za-z0-9_-]{20,200}$/;
const KINDS = { task: ['taskDb', 'taskMap', 'notion_task_db', 'notion_task_map', 'tasks'], memo: ['memoDb', 'memoMap', 'notion_memo_db', 'notion_memo_map', 'memos'] };

const settings = (env, userId) => env.DB.prepare(
  'SELECT notion_enabled, notion_token, notion_task_db, notion_task_map, notion_memo_db, notion_memo_map FROM users WHERE id = ?',
).bind(userId).first();

async function view(env, userId) {
  const s = await settings(env, userId);
  const count = (table) => `SELECT COUNT(*) FROM ${table} WHERE user_id = ?1 AND notion_dirty = 1`;
  const stats = await env.DB.prepare(
    `SELECT (${count('tasks')}) + (${count('memos')}) AS waiting,
            (${count('tasks')} AND notion_tries > 0) + (${count('memos')} AND notion_tries > 0) AS failed,
            COALESCE((SELECT notion_error FROM tasks WHERE user_id = ?1 AND notion_dirty = 1 AND notion_tries > 0 ORDER BY updated_at DESC LIMIT 1),
                     (SELECT data ->> '$.notion.error' FROM memos WHERE user_id = ?1 AND notion_dirty = 1 AND notion_tries > 0 ORDER BY updated_at DESC LIMIT 1)) AS last_error`,
  ).bind(userId).first();
  const json = (v) => (v ? JSON.parse(v) : null);
  return {
    enabled: s.notion_enabled === 1, hasToken: !!s.notion_token,
    taskDb: s.notion_task_db ?? null, taskMap: json(s.notion_task_map),
    memoDb: s.notion_memo_db ?? null, memoMap: json(s.notion_memo_map),
    waiting: stats.waiting ?? 0, failed: stats.failed ?? 0, lastError: stats.last_error ?? null,
  };
}

/** 노션 오류 → 사용자에게 보여줄 400 오류 */
async function friendly(request) {
  try {
    return await request();
  } catch (e) {
    if (!(e instanceof NotionError)) throw e;
    throw new HttpError(400, e.status === 401 ? '토큰이 맞지 않아요. 노션 통합 토큰을 다시 확인해 주세요'
      : e.status === 404 ? '데이터베이스를 찾을 수 없어요. 링크와, 그 데이터베이스의 [연결]에 통합을 추가했는지 확인해 주세요'
        : e.message);
  }
}

async function tokenOf(env, saved, body) {
  const token = body?.token ? String(body.token).trim() : await openToken(env, saved.notion_token);
  if (!token) throw new HttpError(400, '노션 통합 토큰을 입력해 주세요');
  if (!TOKEN_PATTERN.test(token)) throw new HttpError(400, '노션 통합 토큰 모양이 아니에요');
  return token;
}

const dbIdOf = (input) => notionId(input) ?? (() => { throw new HttpError(400, '데이터베이스 링크(또는 ID)를 확인해 주세요'); })();

/** [path]가 노션 설정 API면 [응답 내용], 아니면 null */
export async function notionRoute(path, method, user, request, env, ctx) {
  if (!path.startsWith('/api/notion')) return null;
  const saved = await settings(env, user.id);
  const body = method === 'POST' || method === 'PUT' ? await readJson(request) : null;
  if (path === '/api/notion/inspect' && method === 'POST') {
    const token = await tokenOf(env, saved, body);
    const id = dbIdOf(body?.db);
    return [{ id, ...(await friendly(() => inspectDb(token, id))) }];
  }
  if (path === '/api/notion/check' && method === 'POST') {
    const token = await tokenOf(env, saved, body);
    for (const db of [body?.taskDb ?? saved.notion_task_db, body?.memoDb ?? saved.notion_memo_db].filter(Boolean)) {
      await friendly(() => inspectDb(token, dbIdOf(db)));
    }
    return [{ ok: true, message: '노션 데이터베이스에 연결할 수 있어요' }];
  }
  if (path === '/api/notion/backfill' && method === 'POST') {
    const table = body?.target === 'memos' ? 'memos' : 'tasks';
    const count = await markExisting(env, user.id, table);
    if (count) ctx?.waitUntil?.(syncNotion(env, user.id).catch(() => {}));
    return [{ count }];
  }
  if (path !== '/api/notion') return null;
  if (method === 'GET') return [await view(env, user.id)];
  if (method === 'DELETE') {
    await env.DB.prepare(
      `UPDATE users SET notion_enabled = 0, notion_token = NULL, notion_task_db = NULL, notion_task_map = NULL,
         notion_memo_db = NULL, notion_memo_map = NULL WHERE id = ?`,
    ).bind(user.id).run();
    return [await view(env, user.id)];
  }
  if (method !== 'PUT') return null;
  const next = { ...saved };
  if (body?.token) next.notion_token = await sealToken(env, await tokenOf(env, saved, body));
  for (const [kind, [dbKey, mapKey, dbCol, mapCol, table]] of Object.entries(KINDS)) {
    if (!(dbKey in (body ?? {}))) continue;
    const id = body[dbKey] ? dbIdOf(body[dbKey]) : null;
    next[dbCol] = id;
    next[mapCol] = null;
    if (id) {
      const token = await tokenOf(env, saved, body);
      const db = await friendly(() => inspectDb(token, id));
      next[mapCol] = JSON.stringify(await friendly(async () => checkMap(kind, body[mapKey], db)));
    }
    // 다른 데이터베이스로 바꾸면 예전 페이지 연결을 끊는다 (다음 수정이나 [기존 항목 보내기] 때 새 DB에 만든다)
    if (id !== saved[dbCol]) {
      await env.DB.prepare(`UPDATE ${table} SET notion_page_id = NULL, notion_body_hash = NULL, notion_dirty = 0 WHERE user_id = ?`)
        .bind(user.id).run();
    }
  }
  const enabled = body?.enabled ?? saved.notion_enabled === 1;
  if (enabled && !next.notion_token) throw new HttpError(400, '노션 통합 토큰을 입력해 주세요');
  if (enabled && !next.notion_task_db && !next.notion_memo_db) throw new HttpError(400, '연결할 노션 데이터베이스를 하나 이상 정해 주세요');
  await env.DB.prepare(
    `UPDATE users SET notion_enabled = ?, notion_token = ?, notion_task_db = ?, notion_task_map = ?,
       notion_memo_db = ?, notion_memo_map = ? WHERE id = ?`,
  ).bind(enabled ? 1 : 0, next.notion_token, next.notion_task_db, next.notion_task_map,
    next.notion_memo_db, next.notion_memo_map, user.id).run();
  if (enabled) ctx?.waitUntil?.(syncNotion(env, user.id).catch(() => {}));
  return [await view(env, user.id)];
}
