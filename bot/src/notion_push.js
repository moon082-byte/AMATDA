// 할 일·메모 → 사용자가 연결한 노션 데이터베이스에 반영 (앱 → 노션 한 방향)
// - 바뀐 행을 '반영할 것'(notion_dirty)으로 표시하고 바로 한 번, 실패하면 1분마다 다시 시도 (최대 5번 연속)
// - 새 항목: 페이지 생성 / 수정: 속성 갱신(본문이 바뀌었으면 본문도 다시) / 삭제: 노션 휴지통으로
// - 메모는 결과를 data.notion {pageId, syncedFor, error, errorFor}에 넣어 앱이 '노션 저장됨/실패'를 보여준다

import { sha256Hex } from './crypto.js';
import { NotionError, notion, openToken } from './notion.js';
import { memoBody, memoProperties, taskBody, taskProperties } from './notion_props.js';

/** 연속으로 이만큼 실패하면 다음 수정 때까지 다시 시도하지 않는다 */
export const NOTION_MAX_TRIES = 5;
/** 한 번에 쓰는 노션 호출 수 (요청당 외부 호출 한도 50 안쪽) */
export const NOTION_BUDGET = 40;

/** 표 → 사용자 설정 칸 */
const TARGET = { memos: { db: 'notion_memo_db', map: 'notion_memo_map' }, tasks: { db: 'notion_task_db', map: 'notion_task_map' } };
const connected = (table, u = 'u') =>
  `${u}.notion_enabled = 1 AND ${u}.${TARGET[table].db} IS NOT NULL AND ${u}.${TARGET[table].map} IS NOT NULL`;

/** [ids] 행들을 노션에 반영할 것으로 표시한다 (그 표를 연결한 계정만). 표시했으면 true */
export async function markNotionDirty(env, userId, table, ids) {
  if (!ids.length) return false;
  const res = await env.DB.prepare(
    `UPDATE ${table} SET notion_dirty = 1, notion_tries = 0
     WHERE user_id = ?1 AND id IN (SELECT value FROM json_each(?2))
       AND EXISTS (SELECT 1 FROM users u WHERE u.id = ?1 AND ${connected(table)})`,
  ).bind(userId, JSON.stringify([...new Set(ids)])).run();
  return (res.meta?.changes ?? 0) > 0;
}

/** 동기화로 바뀐 행들 → 표시 (할 일은 세부 항목·메모가 바뀌어도 다시 보낸다) */
export async function markChanges(env, userId, changes) {
  const tasks = [
    ...(changes.tasks ?? []).map((r) => r.id),
    ...[...(changes.sub_tasks ?? []), ...(changes.notes ?? [])].map((r) => r.parentId).filter(Boolean),
  ];
  const memos = await markNotionDirty(env, userId, 'memos', (changes.memos ?? []).map((r) => r.id));
  return (await markNotionDirty(env, userId, 'tasks', tasks)) || memos;
}

/** [기존 항목 보내기]: 아직 노션 페이지가 없는 항목을 모두 표시하고 개수를 돌려준다 */
export async function markExisting(env, userId, table) {
  const res = await env.DB.prepare(
    `UPDATE ${table} SET notion_dirty = 1, notion_tries = 0
     WHERE user_id = ?1 AND deleted = 0 AND notion_page_id IS NULL
       AND EXISTS (SELECT 1 FROM users u WHERE u.id = ?1 AND ${connected(table)})`,
  ).bind(userId).run();
  return res.meta?.changes ?? 0;
}

class OutOfBudget extends Error {}

/** 처리 결과 저장. 그 사이 항목이 또 바뀌었으면(version이 다르면) 다음에 다시 반영한다 */
async function finish(env, table, row, { pageId, error = null, bodyHash = row.notion_body_hash }) {
  const memo = table === 'memos' && !row.deleted;
  const data = memo ? JSON.parse(row.data) : null;
  const info = !memo ? null : error
    ? { ...(data.notion ?? {}), pageId, error, errorFor: data.updatedAt ?? null }
    : { pageId, syncedFor: data.updatedAt ?? null, error: null };
  // 메모는 앱이 상태를 받아 가도록 순번을 올린다
  const version = memo
    ? (await env.DB.prepare('UPDATE users SET version = version + 1 WHERE id = ? RETURNING version').bind(row.user_id).first()).version
    : null;
  await env.DB.prepare(
    `UPDATE ${table} SET notion_page_id = ?1, notion_body_hash = ?8,
       notion_tries = CASE WHEN ?2 IS NULL THEN 0 ELSE notion_tries + 1 END,
       notion_dirty = CASE WHEN ?2 IS NULL AND version = ?3 THEN 0 ELSE notion_dirty END,
       ${table === 'tasks' ? 'notion_error = ?2,' : ''}
       data = CASE WHEN ?4 IS NULL THEN data ELSE json_set(data, '$.notion', json(?5)) END,
       version = COALESCE(?4, version)
     WHERE user_id = ?6 AND id = ?7`,
  ).bind(pageId, error, row.version, version, JSON.stringify(info), row.user_id, row.id, pageId ? bodyHash : null).run();
}

/** 노션에서 지웠거나 휴지통에 넣은 페이지라 새로 만들어야 하는 오류인지 */
const gone = (e) => e instanceof NotionError && (e.status === 404 || (e.status === 400 && /archiv|trash/i.test(e.message)));

const children = (env, table, row) => env.DB.prepare(
  `SELECT data FROM ${table} WHERE user_id = ? AND parent_id = ? AND deleted = 0 ORDER BY position, id`,
).bind(row.user_id, row.id).all().then(({ results }) => results.map((r) => JSON.parse(r.data)));

async function pushOne(env, table, row, budget) {
  let pageId = row.notion_page_id;
  try {
    const token = await openToken(env, row.token);
    if (!token) throw new Error('노션 토큰을 읽을 수 없어요. 설정에서 토큰을 다시 넣어 주세요');
    const call = (method, path, body) => {
      if (budget.left-- <= 0) throw new OutOfBudget();
      return notion(token, method, path, body);
    };
    if (row.deleted) {
      if (pageId) await call('PATCH', `/pages/${pageId}`, { archived: true }).catch((e) => { if (!gone(e)) throw e; });
      return await finish(env, table, row, { pageId: null });
    }
    const item = JSON.parse(row.data);
    const map = JSON.parse(row.map);
    const notes = table === 'tasks' ? await children(env, 'notes', row) : [];
    const props = (isNew) => (table === 'tasks' ? taskProperties(item, notes, map) : memoProperties(item, map, { isNew }));
    const body = table === 'tasks' ? taskBody(item, await children(env, 'sub_tasks', row), notes) : memoBody(item);
    const bodyHash = await sha256Hex(JSON.stringify(body));
    if (pageId) {
      try {
        await call('PATCH', `/pages/${pageId}`, { properties: props(false) });
        if (bodyHash !== row.notion_body_hash) {
          const { results = [] } = await call('GET', `/blocks/${pageId}/children?page_size=100`);
          for (const b of results) await call('DELETE', `/blocks/${b.id}`);
          if (body.length) await call('PATCH', `/blocks/${pageId}/children`, { children: body });
        }
      } catch (e) {
        if (!gone(e)) throw e;
        pageId = null;
      }
    }
    pageId ??= (await call('POST', '/pages', { parent: { database_id: row.db }, properties: props(true), children: body })).id;
    await finish(env, table, row, { pageId, bodyHash });
  } catch (e) {
    if (e instanceof OutOfBudget) throw e; // 다음 차례(1분 뒤)에 이어서
    console.error('노션 반영 실패', table, row.id, e.message);
    await finish(env, table, row, { pageId, error: String(e.message ?? e).slice(0, 200) });
  }
}

/** 반영할 항목을 노션에 보낸다 ([userId]를 주면 그 계정만) */
export async function syncNotion(env, userId = null) {
  const budget = { left: NOTION_BUDGET };
  const done = new Set();
  try {
    for (const table of ['memos', 'tasks']) {
      while (budget.left > 0) {
        const { results } = await env.DB.prepare(
          `SELECT r.user_id, r.id, r.data, r.deleted, r.version, r.notion_page_id, r.notion_body_hash,
                  u.notion_token AS token, u.${TARGET[table].db} AS db, u.${TARGET[table].map} AS map
           FROM ${table} r JOIN users u ON u.id = r.user_id
           WHERE r.notion_dirty = 1 AND r.notion_tries < ${NOTION_MAX_TRIES} AND ${connected(table)}
             AND (?1 IS NULL OR r.user_id = ?1)
           ORDER BY r.updated_at LIMIT 10`,
        ).bind(userId).all();
        const fresh = results.filter((r) => !done.has(`${table}:${r.user_id}:${r.id}`));
        if (!fresh.length) break;
        for (const row of fresh) {
          done.add(`${table}:${row.user_id}:${row.id}`);
          await pushOne(env, table, row, budget);
        }
      }
    }
  } catch (e) {
    if (!(e instanceof OutOfBudget)) throw e;
  }
}
