// 기기 간 데이터 동기화: POST /api/sync
//
// 요청: { since: <마지막으로 받은 순번>, changes: { rooms: [...], tasks: [...], ... } }
// 응답: { version: <새 순번>, more: <더 받을 게 있는지>, changes: { 표: [since 이후 바뀐 행] } }
//
// - 올린 변경은 받은 순서대로 사용자별 순번(users.version)을 매겨 저장한다 (나중에 저장한 쪽이 이김)
// - 삭제는 deleted=1로 남겨 다른 기기에도 전달한다
// - 무료 요금제의 요청당 쿼리 수 제한에 맞게 표마다 JSON 한 번으로 넣는다

import { MAX_PULL_ROWS, SYNC_TABLES, sanitizeSyncChanges } from './logic.js';
import { validate } from './http.js';

export async function sync(user, body, env) {
  const { since, changes, total } = validate(() => sanitizeSyncChanges(body));
  if (total > 0) await saveChanges(env, user.id, changes, total);

  const union = SYNC_TABLES.map(
    (t) => `SELECT '${t}' AS tbl, id, parent_id, position, data, deleted, version
            FROM ${t} WHERE user_id = ?1 AND version > ?2`,
  ).join(' UNION ALL ');
  const [{ results }, head] = await Promise.all([
    env.DB.prepare(`${union} ORDER BY version LIMIT ${MAX_PULL_ROWS + 1}`).bind(user.id, since).all(),
    env.DB.prepare('SELECT version FROM users WHERE id = ?').bind(user.id).first(),
  ]);
  const more = results.length > MAX_PULL_ROWS;
  const rows = results.slice(0, MAX_PULL_ROWS);

  const grouped = Object.fromEntries(SYNC_TABLES.map((t) => [t, []]));
  for (const r of rows) {
    grouped[r.tbl].push({
      id: r.id,
      parentId: r.parent_id,
      position: r.position,
      data: r.data,
      deleted: r.deleted === 1,
    });
  }
  return {
    version: more ? rows[rows.length - 1].version : head.version,
    more,
    changes: grouped,
  };
}

async function saveChanges(env, userId, changes, total) {
  const bumped = await env.DB.prepare(
    'UPDATE users SET version = version + ? WHERE id = ? RETURNING version',
  ).bind(total, userId).first();
  let next = bumped.version - total; // 이번 변경들의 순번: next+1 ~ next+total
  const now = Date.now();
  const statements = [];
  for (const table of SYNC_TABLES) {
    const list = changes[table];
    if (!list.length) continue;
    statements.push(env.DB.prepare(
      `INSERT INTO ${table} (user_id, id, parent_id, position, data, deleted, version, updated_at)
       SELECT ?1, j.value ->> 'id', j.value ->> 'parentId', j.value ->> 'position',
              j.value ->> 'data', j.value ->> 'deleted', ?2 + j.key + 1, ?3
       FROM json_each(?4) AS j WHERE true
       ON CONFLICT (user_id, id) DO UPDATE SET
         parent_id = excluded.parent_id, position = excluded.position, data = excluded.data,
         deleted = excluded.deleted, version = excluded.version, updated_at = excluded.updated_at`,
    ).bind(userId, next, now, JSON.stringify(list)));
    next += list.length;
  }
  await env.DB.batch(statements);
}
