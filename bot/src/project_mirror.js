// 배정된 세부업무 ↔ 담당자 개인 할일 (양방향)
// - 서버가 담당자의 tasks 표(기기 동기화 데이터)에 연결된 할 일 'pt_<세부업무 id>'를 넣고 맞춘다.
//   제목·마감·완료는 프로젝트가 기준(잠금), 업무방 태그·리마인더·세부 항목·메모는 담당자가 바꿀 수 있다.
// - 담당자 기기가 동기화로 올린 변경은 project_review.js의 guardMirrors가 검사한다.


export const mirrorId = (taskId) => `pt_${taskId}`;
export const taskIdOf = (id) => (id.startsWith('pt_') ? id.slice(3) : null);
const iso = (ms) => (ms ? new Date(ms).toISOString() : null);
export const parse = (s) => {
  try {
    return JSON.parse(s) ?? {};
  } catch {
    return {};
  }
};

export const JOINED = `SELECT t.*, p.name AS project_name, r.name AS room_name, r.leader_id
  FROM project_tasks t JOIN projects p ON p.id = t.project_id JOIN project_rooms r ON r.id = t.room_id`;

/** 개인 할일 내용: 담당자가 바꾼 칸([own])은 두고, 잠긴 칸은 프로젝트 값으로 */
export function mirrorData(t, own = {}) {
  return {
    ...own,
    title: t.title,
    isDone: !!t.done_at,
    dueDate: iso(t.due_at),
    completedAt: iso(t.done_at),
    priority: own.priority ?? 'medium',
    createdAt: own.createdAt ?? iso(t.created_at),
    remindAt: Array.isArray(own.remindAt) ? own.remindAt : [],
    project: {
      roomId: t.room_id, roomName: t.room_name, projectName: t.project_name, taskId: t.id,
      reviewRequested: !!t.review_at && !t.done_at, // 검토중 (담당자가 완료 보고함)
    },
  };
}

/** 사용자 데이터 순번을 하나 올리고 새 순번을 돌려준다 (그 기기가 다음 동기화 때 받아 간다) */
const bump = async (env, userId) =>
  (await env.DB.prepare('UPDATE users SET version = version + 1 WHERE id = ? RETURNING version').bind(userId).first())
    .version;

/** 세부업무 [t]의 개인 할일을 담당자 쪽에 쓴다. 내용이 같으면 건너뛴다 ([force]면 다시 내려보낸다) */
export async function writeMirror(env, t, force = false) {
  const id = mirrorId(t.id);
  const prev = await env.DB.prepare('SELECT data, deleted FROM tasks WHERE user_id = ? AND id = ?')
    .bind(t.assignee_id, id).first();
  const live = prev && !prev.deleted;
  const json = JSON.stringify(mirrorData(t, live ? parse(prev.data) : {}));
  if (live && prev.data === json && !force) return;
  const version = await bump(env, t.assignee_id);
  await env.DB.prepare(
    `INSERT INTO tasks (user_id, id, parent_id, position, data, deleted, version, updated_at)
     VALUES (?1, ?2, NULL, 0, ?3, 0, ?4, ?5)
     ON CONFLICT (user_id, id) DO UPDATE SET data = ?3, deleted = 0, version = ?4, updated_at = ?5`,
  ).bind(t.assignee_id, id, json, version, Date.now()).run();
}

/** [where] 조건(별칭 t = project_tasks)에 맞는 배정 업무들의 개인 할일을 다시 맞춘다 */
export async function refreshMirrors(env, where, ...binds) {
  const { results } = await env.DB.prepare(`${JOINED} WHERE t.assignee_id IS NOT NULL AND (${where})`)
    .bind(...binds).all();
  for (const t of results) await writeMirror(env, t);
}

/** [userId]의 개인 할일에서 세부업무 [taskId]를 지운다 (모든 기기에서 사라진다) */
export async function removeMirror(env, userId, taskId) {
  if (!userId) return;
  const row = await env.DB.prepare('SELECT deleted FROM tasks WHERE user_id = ? AND id = ?')
    .bind(userId, mirrorId(taskId)).first();
  if (!row || row.deleted) return;
  const version = await bump(env, userId);
  await env.DB.prepare('UPDATE tasks SET deleted = 1, version = ?, updated_at = ? WHERE user_id = ? AND id = ?')
    .bind(version, Date.now(), userId, mirrorId(taskId)).run();
}

/** [where]에 맞는 진행 중 배정 업무들의 개인 할일을 지운다 (업무·프로젝트·방 삭제, 내보내기) */
export async function removeOpenMirrors(env, where, ...binds) {
  const { results } = await env.DB.prepare(
    `SELECT id, assignee_id FROM project_tasks t WHERE t.assignee_id IS NOT NULL AND t.done_at IS NULL AND (${where})`,
  ).bind(...binds).all();
  for (const t of results) await removeMirror(env, t.assignee_id, t.id);
}

/** guardMirrors가 돌려준 업무들을 다시 내려보낸다 */
export async function resendMirrors(env, tasks) {
  for (const t of tasks) await writeMirror(env, t, true);
}
