// 프로젝트 API (로그인 필요, 팀장만)
// - POST   /api/project-rooms/:id/projects   프로젝트 추가 {name, dueAt}
// - PUT    /api/projects/:id                  프로젝트 수정 (담당자 개인 할일의 프로젝트 이름도 맞춘다)
// - DELETE /api/projects/:id                  프로젝트와 세부업무 삭제 (진행 중 업무 담당자에게 알림, 개인 할일에서 지움)
// 세부업무는 project_tasks.js

import { readJson } from './http.js';
import { notifyUsers } from './notify.js';
import { dueAt, newId, requireProject, requireRoom, roomDetail, roomRow, text, touchRoom } from './project_db.js';
import { refreshMirrors, removeOpenMirrors } from './project_mirror.js';
import { projectTaskRoute } from './project_tasks.js';

export const leaderView = (env, roomId, user) =>
  roomDetail(env, roomId, { id: user.id, role: 'leader', status: 'active' });

/** 세부업무 알림 한 건 */
export const taskNote = (kind, title, room, task) => ({
  kind, title, body: `${room.name}방 - ${task.title}`, target: `project:${room.id}`,
});

export async function projectItemRoute(path, method, user, request, env, ctx) {
  const m = /^\/api\/project-rooms\/([A-Za-z0-9_-]+)\/projects$/.exec(path);
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

  const p = /^\/api\/projects\/([A-Za-z0-9_-]+)$/.exec(path);
  if (!p) return projectTaskRoute(path, method, user, request, env, ctx);
  const { project } = await requireProject(env, p[1], user, { leader: true });
  const roomId = project.room_id;
  if (method === 'PUT') {
    const raw = await readJson(request);
    await env.DB.batch([
      env.DB.prepare('UPDATE projects SET name = ?, due_at = ? WHERE id = ?')
        .bind(text(raw?.name, 40, '프로젝트 이름'), dueAt(raw?.dueAt), project.id),
      touchRoom(env, roomId),
    ]);
    await refreshMirrors(env, 't.project_id = ?', project.id);
    return [await leaderView(env, roomId, user)];
  }
  if (method === 'DELETE') {
    const { results } = await env.DB.prepare(
      'SELECT title, assignee_id FROM project_tasks WHERE project_id = ? AND done_at IS NULL',
    ).bind(project.id).all();
    await removeOpenMirrors(env, 't.project_id = ?', project.id);
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
