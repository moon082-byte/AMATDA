// 기기 간 데이터 동기화: POST /api/sync
//
// 요청: { since: <마지막으로 받은 순번>, device: <이 기기 번호>, changes: { rooms: [...], tasks: [...], ... } }
// 응답: { version: <새 순번>, more: <더 받을 게 있는지>, changes: { 표: [since 이후 바뀐 행] } }
//
// - 올린 변경은 받은 순서대로 사용자별 순번(users.version)을 매겨 저장한다 (나중에 저장한 쪽이 이김)
// - 삭제는 deleted=1로 남겨 다른 기기에도 전달한다
// - 무료 요금제의 요청당 쿼리 수 제한에 맞게 표마다 JSON 한 번으로 넣는다

import { cleanDevice, recordTaskChanges } from './inbox.js';
import { markChanges, syncNotion } from './notion_push.js';
import { resendMirrors } from './project_mirror.js';
import { guardMirrors } from './project_review.js';
import { MAX_PULL_ROWS, SYNC_TABLES, sanitizeSyncChanges } from './logic.js';
import { validate } from './http.js';

export async function sync(user, body, env, ctx) {
  const { since, changes } = validate(() => sanitizeSyncChanges(body));
  // 프로젝트 업무(pt_)는 잠긴 칸을 되돌리고, 체크하면 완료 보고로 처리한다
  const resend = await guardMirrors(env, ctx, user, changes);
  const total = Object.values(changes).reduce((n, list) => n + list.length, 0);
  if (total > 0) {
    // 저장하기 전에 이전 내용과 비교해, 다른 기기 알림함에 보일 할 일 변경을 남긴다
    await recordTaskChanges(env, user.id, cleanDevice(body?.device), changes.tasks);
    // 노션 연동을 켠 계정은 바뀐 할 일·메모를 노션에 바로 반영한다 (실패하면 1분마다 다시)
    if (await saveChanges(env, user.id, changes, total)) ctx?.waitUntil?.(syncNotion(env, user.id).catch(() => {}));
  }
  await resendMirrors(env, resend);

  // D1은 UNION으로 이을 수 있는 SELECT가 5개까지라, 표마다 따로 읽어(한 번의 batch) 순번순으로 합친다.
  // 표마다 앞의 MAX+1개만 읽어도 전체에서 앞의 MAX+1개는 빠지지 않는다.
  const [head, ...lists] = await env.DB.batch([
    env.DB.prepare('SELECT version FROM users WHERE id = ?').bind(user.id),
    ...SYNC_TABLES.map((t) => env.DB.prepare(
      `SELECT '${t}' AS tbl, id, parent_id, position, data, deleted, version
       FROM ${t} WHERE user_id = ?1 AND version > ?2 ORDER BY version LIMIT ${MAX_PULL_ROWS + 1}`,
    ).bind(user.id, since)),
  ]);
  const results = lists.flatMap((l) => l.results).sort((a, b) => a.version - b.version);
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
    version: more ? rows[rows.length - 1].version : head.results[0].version,
    more,
    changes: grouped,
  };
}

/**
 * 변경을 사용자 순번을 매겨 저장한다 ([changes]는 SYNC_TABLES 표마다 행 목록, 텔레그램 봇도 쓴다).
 * 노션에 반영할 할 일·메모가 생겼으면 true (1분마다 도는 작업도 보낸다)
 */
export async function saveChanges(env, userId, changes, total) {
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
  return markChanges(env, userId, changes);
}
