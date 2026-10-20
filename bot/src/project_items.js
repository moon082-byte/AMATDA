// 프로젝트·세부업무 API (로그인 필요)
// - POST   /api/project-rooms/:id/projects   프로젝트 추가 {name, dueAt} (팀장)
// - PUT    /api/projects/:id                  프로젝트 수정 (팀장)
// - DELETE /api/projects/:id                  프로젝트와 세부업무 삭제 (팀장)
// - POST   /api/projects/:id/tasks            세부업무 추가 {title, assigneeId, dueAt} (팀장) → 담당자에게 알림
// - PUT    /api/project-tasks/:id             세부업무 수정 (팀장) → 담당자에게 알림
// - DELETE /api/project-tasks/:id             세부업무 삭제 (팀장) → 담당자에게 알림
// - POST   /api/project-tasks/:id/complete    완료 보고 (담당자 본인) → 팀장에게 알림

import { HttpError, readJson } from './http.js';
import { notifyUsers } from './notify.js';
import {
  dueAt, handleOf, membership, newId, requireProject, requireRoom, requireTask, roomDetail, roomRow, text, touchRoom,
} from './project_db.js';

/** 담당자는 그 방에 참여 중인 사람이어야 한다 (비우면 미배정) */
async function assignee(env, roomId, value) {
  if (!value) return null;
  const m = await membership(env, roomId, String(value));
  if (m?.status !== 'active') throw new HttpError(400, '담당자는 이 방의 팀원 중에서 골라 주세요');
  return String(value);
}

const leaderView = (env, roomId, user) => roomDetail(env, roomId, { id: user.id, role: 'leader', status: 'active' });

/** 세부업무 알림 한 건 */
const taskNote = (kind, title, room, task) => ({
  kind, title, body: `${room.name}방 - ${task.title}`, target: `project:${room.id}`,
});

export async function projectItemRoute(path, method, user, request, env, ctx) {
  let m = /^\/api\/project-rooms\/([A-Za-z0-9_-]+)\/projects$/.exec(path);
  if (m && method === 'POST') {
    await requireRoom(env, m[1], user, { leader: true });
    const raw = await readJson(request);
    await env.DB.batch([
      env.DB.prepare('INSERT INTO projects (id, room_id, name, due_at, position, created_at) VALUES (?, ?, ?, ?, ?, ?)')
        .bind(newId('prj'), m[1], text(raw?.name, 40, '프로젝트 이름'), dueAt(raw?.dueAt), Date.now(), Date.now()),
      touchRoom(env, m[1]),
    ]);
    return [await leaderView(env, m[1], user)];
  }

  m = /^\/api\/projects\/([A-Za-z0-9_-]+)(\/tasks)?$/.exec(path);
  if (m) {
    const { project } = await requireProject(env, m[1], user, { leader: true });
    const roomId = project.room_id;
    if (m[2] && method === 'POST') {
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
      await notifyUsers(env, ctx, [task.assigneeId], taskNote('project_assigned', '업무 배정', await roomRow(env, roomId), task), user.id);
      return [await leaderView(env, roomId, user)];
    }
    if (m[2]) return null;
    if (method === 'PUT') {
      const raw = await readJson(request);
      await env.DB.batch([
        env.DB.prepare('UPDATE projects SET name = ?, due_at = ? WHERE id = ?')
          .bind(text(raw?.name, 40, '프로젝트 이름'), dueAt(raw?.dueAt), project.id),
        touchRoom(env, roomId),
      ]);
      return [await leaderView(env, roomId, user)];
    }
    if (method === 'DELETE') {
      const { results } = await env.DB.prepare(
        'SELECT title, assignee_id FROM project_tasks WHERE project_id = ? AND done_at IS NULL',
      ).bind(project.id).all();
      await env.DB.batch([
        env.DB.prepare('DELETE FROM project_tasks WHERE project_id = ?').bind(project.id),
        env.DB.prepare('DELETE FROM projects WHERE id = ?').bind(project.id),
        touchRoom(env, roomId),
      ]);
      const room = await roomRow(env, roomId);
      for (const t of results) {
        await notifyUsers(env, ctx, [t.assignee_id], taskNote('project_deleted', '업무 삭제', room, t), user.id);
      }
      return [await leaderView(env, roomId, user)];
    }
    return null;
  }

  m = /^\/api\/project-tasks\/([A-Za-z0-9_-]+)(\/complete)?$/.exec(path);
  if (!m) return null;
  if (m[2] && method === 'POST') {
    const { task, member } = await requireTask(env, m[1], user);
    if (task.assignee_id !== user.id) throw new HttpError(403, '내가 맡은 업무만 완료할 수 있어요');
    if (task.done_at) return [await roomDetail(env, task.room_id, { id: user.id, ...member })];
    await env.DB.batch([
      env.DB.prepare('UPDATE project_tasks SET done_at = ?, updated_at = ? WHERE id = ?').bind(Date.now(), Date.now(), task.id),
      touchRoom(env, task.room_id),
    ]);
    const [room, me] = await Promise.all([
      roomRow(env, task.room_id), env.DB.prepare('SELECT nickname, tag, name FROM users WHERE id = ?').bind(user.id).first(),
    ]);
    await notifyUsers(env, ctx, [room.leader_id], {
      ...taskNote('project_done', '업무 완료 보고', room, task), body: `${handleOf(me)}님이 ${room.name}방 - ${task.title} 완료를 보고했어요`,
    }, user.id);
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
    if (next.assigneeId !== task.assignee_id) {
      await notifyUsers(env, ctx, [task.assignee_id], taskNote('project_deleted', '업무 배정 취소', room, task), user.id);
      await notifyUsers(env, ctx, [next.assigneeId], taskNote('project_assigned', '업무 배정', room, next), user.id);
    } else if (next.title !== task.title || next.dueAt !== task.due_at) {
      await notifyUsers(env, ctx, [next.assigneeId], taskNote('project_edited', '업무 수정', room, next), user.id);
    }
    return [await leaderView(env, task.room_id, user)];
  }
  if (method === 'DELETE') {
    await env.DB.batch([env.DB.prepare('DELETE FROM project_tasks WHERE id = ?').bind(task.id), touchRoom(env, task.room_id)]);
    if (!task.done_at) {
      await notifyUsers(env, ctx, [task.assignee_id], taskNote('project_deleted', '업무 삭제', room, task), user.id);
    }
    return [await leaderView(env, task.room_id, user)];
  }
  return null;
}
