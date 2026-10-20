// 세부업무 API (로그인 필요)
// - POST   /api/projects/:id/tasks            세부업무 추가 {title, assigneeId, dueAt} (팀장) → 담당자 개인 할일·알림
// - PUT    /api/project-tasks/:id             세부업무 수정 (팀장) → 담당자 개인 할일 맞춤·알림
// - DELETE /api/project-tasks/:id             세부업무 삭제 (팀장) → 담당자 개인 할일에서 지움·알림
// - POST   /api/project-tasks/:id/complete    완료 보고 (담당자 본인) → 팀장에게 알림

import { HttpError, readJson } from './http.js';
import { notifyUsers } from './notify.js';
import {
  dueAt, membership, newId, requireProject, requireTask, roomDetail, roomRow, text, touchRoom,
} from './project_db.js';
import { leaderView, taskNote } from './project_items.js';
import { completeProjectTask, refreshMirrors, removeMirror } from './project_mirror.js';

/** 담당자는 그 방에 참여 중인 사람이어야 한다 (비우면 미배정) */
async function assignee(env, roomId, value) {
  if (!value) return null;
  const m = await membership(env, roomId, String(value));
  if (m?.status !== 'active') throw new HttpError(400, '담당자는 이 방의 팀원 중에서 골라 주세요');
  return String(value);
}

export async function projectTaskRoute(path, method, user, request, env, ctx) {
  let m = /^\/api\/projects\/([A-Za-z0-9_-]+)\/tasks$/.exec(path);
  if (m && method === 'POST') {
    const { project } = await requireProject(env, m[1], user, { leader: true });
    const roomId = project.room_id;
    const raw = await readJson(request);
    const task = {
      id: newId('ptk'), title: text(raw?.title, 80, '업무 이름'),
      assigneeId: await assignee(env, roomId, raw?.assigneeId), dueAt: dueAt(raw?.dueAt),
    };
    const now = Date.now();
    await env.DB.batch([
      env.DB.prepare(
        `INSERT INTO project_tasks (id, project_id, room_id, title, assignee_id, due_at, position, created_at, updated_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`,
      ).bind(task.id, project.id, roomId, task.title, task.assigneeId, task.dueAt, now, now, now),
      touchRoom(env, roomId),
    ]);
    await refreshMirrors(env, 't.id = ?', task.id);
    await notifyUsers(env, ctx, [task.assigneeId], taskNote('project_assigned', '업무 배정', await roomRow(env, roomId), task), user.id);
    return [await leaderView(env, roomId, user)];
  }

  m = /^\/api\/project-tasks\/([A-Za-z0-9_-]+)(\/complete)?$/.exec(path);
  if (!m) return null;
  if (m[2] && method === 'POST') {
    const { task, member } = await requireTask(env, m[1], user);
    if (task.assignee_id !== user.id) throw new HttpError(403, '내가 맡은 업무만 완료할 수 있어요');
    await completeProjectTask(env, ctx, task, user);
    return [await roomDetail(env, task.room_id, { id: user.id, ...member })];
  }
  if (m[2]) return null;

  const { task } = await requireTask(env, m[1], user, { leader: true });
  const room = await roomRow(env, task.room_id);
  if (method === 'PUT') {
    const raw = await readJson(request);
    const next = {
      title: raw?.title === undefined ? task.title : text(raw.title, 80, '업무 이름'),
      assigneeId: raw?.assigneeId === undefined ? task.assignee_id : await assignee(env, task.room_id, raw.assigneeId),
      dueAt: raw?.dueAt === undefined ? task.due_at : dueAt(raw.dueAt),
    };
    await env.DB.batch([
      env.DB.prepare('UPDATE project_tasks SET title = ?, assignee_id = ?, due_at = ?, updated_at = ? WHERE id = ?')
        .bind(next.title, next.assigneeId, next.dueAt, Date.now(), task.id),
      touchRoom(env, task.room_id),
    ]);
    if (next.assigneeId !== task.assignee_id) await removeMirror(env, task.assignee_id, task.id);
    await refreshMirrors(env, 't.id = ?', task.id);
    if (next.assigneeId !== task.assignee_id) {
      await notifyUsers(env, ctx, [task.assignee_id], taskNote('project_deleted', '업무 배정 취소', room, task), user.id);
      await notifyUsers(env, ctx, [next.assigneeId], taskNote('project_assigned', '업무 배정', room, next), user.id);
    } else if (next.title !== task.title || next.dueAt !== task.due_at) {
      await notifyUsers(env, ctx, [next.assigneeId], taskNote('project_edited', '업무 수정', room, next), user.id);
    }
    return [await leaderView(env, task.room_id, user)];
  }
  if (method === 'DELETE') {
    if (!task.done_at) await removeMirror(env, task.assignee_id, task.id);
    await env.DB.batch([env.DB.prepare('DELETE FROM project_tasks WHERE id = ?').bind(task.id), touchRoom(env, task.room_id)]);
    if (!task.done_at) {
      await notifyUsers(env, ctx, [task.assignee_id], taskNote('project_deleted', '업무 삭제', room, task), user.id);
    }
    return [await leaderView(env, task.room_id, user)];
  }
  return null;
}
