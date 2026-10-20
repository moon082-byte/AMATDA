// 배정된 세부업무 ↔ 담당자 개인 할일 (양방향)
// - 서버가 담당자의 tasks 표(기기 동기화 데이터)에 연결된 할 일 'pt_<세부업무 id>'를 넣고 맞춘다.
//   제목·마감·완료는 프로젝트가 기준(잠금), 업무방 태그·리마인더·세부 항목·메모는 담당자가 바꿀 수 있다.
// - 담당자 기기가 동기화로 올린 변경은 guardMirrors가 검사한다: 잠긴 칸은 되돌리고, 체크하면 완료 보고로 처리.

import { notifyUsers } from './notify.js';
import { handleOf, touchRoom } from './project_db.js';

export const mirrorId = (taskId) => `pt_${taskId}`;
const taskIdOf = (id) => (id.startsWith('pt_') ? id.slice(3) : null);
const iso = (ms) => (ms ? new Date(ms).toISOString() : null);
const parse = (s) => {
  try {
    return JSON.parse(s) ?? {};
  } catch {
    return {};
  }
};

const JOINED = `SELECT t.*, p.name AS project_name, r.name AS room_name, r.leader_id
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
    project: { roomId: t.room_id, roomName: t.room_name, projectName: t.project_name, taskId: t.id },
  };
}

/** 사용자 데이터 순번을 하나 올리고 새 순번을 돌려준다 (그 기기가 다음 동기화 때 받아 간다) */
const bump = async (env, userId) =>
  (await env.DB.prepare('UPDATE users SET version = version + 1 WHERE id = ? RETURNING version').bind(userId).first())
    .version;

/** 세부업무 [t]의 개인 할일을 담당자 쪽에 쓴다. 내용이 같으면 건너뛴다 ([force]면 다시 내려보낸다) */
async function writeMirror(env, t, force = false) {
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

/** 담당자 [user]의 완료 보고: 프로젝트에 완료를 기록하고, 개인 할일을 맞추고, 팀장에게 알린다 */
export async function completeProjectTask(env, ctx, task, user) {
  if (task.done_at) return;
  const now = Date.now();
  await env.DB.batch([
    env.DB.prepare('UPDATE project_tasks SET done_at = ?, updated_at = ? WHERE id = ?').bind(now, now, task.id),
    touchRoom(env, task.room_id),
  ]);
  await refreshMirrors(env, 't.id = ?', task.id);
  const [room, me] = await Promise.all([
    env.DB.prepare('SELECT id, name, leader_id FROM project_rooms WHERE id = ?').bind(task.room_id).first(),
    env.DB.prepare('SELECT nickname, tag, name FROM users WHERE id = ?').bind(user.id).first(),
  ]);
  await notifyUsers(env, ctx, [room.leader_id], {
    kind: 'project_done', title: '업무 완료 보고', target: `project:${room.id}`,
    body: `${handleOf(me)}님이 ${room.name}방 - ${task.title} 완료를 보고했어요`,
  }, user.id);
}

/**
 * 동기화로 올라온 개인 할일 중 프로젝트 업무(pt_)를 검사한다 ([changes.tasks]를 고쳐 쓴다).
 * - 내 업무가 아니거나 없어진 업무: 버린다
 * - 잠긴 칸(제목·마감·완료 취소): 프로젝트 값으로 되돌린다
 * - 체크해서 올라오면: 완료 보고 (팀장에게 알림)
 * - 진행 중 업무를 지우면: 지우지 않고 다시 내려보낸다 (완료된 것은 지워도 된다)
 * @returns 저장 뒤 다시 내려보낼 업무 목록
 */
export async function guardMirrors(env, ctx, user, changes) {
  const resend = [];
  const keep = [];
  for (const row of changes.tasks) {
    const taskId = taskIdOf(row.id);
    if (!taskId) {
      keep.push(row);
      continue;
    }
    const t = await env.DB.prepare(`${JOINED} WHERE t.id = ?`).bind(taskId).first();
    if (!t || t.assignee_id !== user.id) continue;
    if (row.deleted) {
      if (t.done_at) keep.push(row);
      else resend.push(t);
      continue;
    }
    const own = parse(row.data);
    if (own.isDone && !t.done_at) {
      await completeProjectTask(env, ctx, t, user);
      t.done_at = Date.now();
    }
    keep.push({ ...row, data: JSON.stringify(mirrorData(t, own)) });
  }
  changes.tasks = keep;
  return resend;
}

/** guardMirrors가 돌려준 업무들을 다시 내려보낸다 */
export async function resendMirrors(env, tasks) {
  for (const t of tasks) await writeMirror(env, t, true);
}
