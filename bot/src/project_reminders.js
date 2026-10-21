// 프로젝트 리마인더: 팀장이 프로젝트에 건 알림 시각(최대 5개)
// 시각이 되면(1분마다 cron) 팀장과 그 프로젝트에 진행 중 업무가 있는 담당자에게 알린다.

import { HttpError } from './http.js';
import { STALE_MS } from './logic.js';
import { notifyUsers } from './notify.js';

export const MAX_PROJECT_REMINDERS = 5;
/** 무료 요금제 외부 호출 한도 안에서 1분에 보내는 프로젝트 리마인더 수 */
const SEND_LIMIT = 3;

/** 앱이 보낸 알림 시각 목록 (epoch ms) → 겹치지 않게 이른 순, 최대 5개 */
export function cleanRemindAt(value) {
  if (value === undefined || value === null) return [];
  if (!Array.isArray(value)) throw new HttpError(400, '리마인더 형식이 잘못됐어요');
  const times = [...new Set(value.map(Number).filter((n) => Number.isFinite(n) && n > 0).map(Math.floor))];
  if (times.length > MAX_PROJECT_REMINDERS) throw new HttpError(400, `리마인더는 ${MAX_PROJECT_REMINDERS}개까지예요`);
  return times.sort((a, b) => a - b);
}

/** 프로젝트의 리마인더를 [times]로 바꾼다 (이미 보낸 시각은 보낸 상태를 유지) */
export function replaceProjectReminders(env, projectId, roomId, times) {
  return [
    env.DB.prepare(
      `DELETE FROM project_reminders WHERE project_id = ?1
       AND fire_at NOT IN (SELECT value FROM json_each(?2))`,
    ).bind(projectId, JSON.stringify(times)),
    env.DB.prepare(
      `INSERT OR IGNORE INTO project_reminders (project_id, room_id, fire_at)
       SELECT ?1, ?2, value FROM json_each(?3)`,
    ).bind(projectId, roomId, JSON.stringify(times)),
  ];
}

/** 방의 프로젝트별 리마인더 시각 { projectId: [ms...] } */
export async function remindersByProject(env, roomId) {
  const { results } = await env.DB.prepare(
    'SELECT project_id, fire_at FROM project_reminders WHERE room_id = ? ORDER BY fire_at',
  ).bind(roomId).all();
  const map = {};
  for (const r of results) (map[r.project_id] ??= []).push(r.fire_at);
  return map;
}

/** 시각이 된 프로젝트 리마인더를 보낸다 (마감이 12시간 넘게 지난 것은 건너뛴다) */
export async function sendDueProjectReminders(env) {
  const now = Date.now();
  const { results } = await env.DB.prepare(
    `SELECT pr.project_id, pr.fire_at, p.name AS project_name, r.id AS room_id, r.name AS room_name, r.leader_id
     FROM project_reminders pr JOIN projects p ON p.id = pr.project_id JOIN project_rooms r ON r.id = pr.room_id
     WHERE pr.sent = 0 AND pr.fire_at <= ?1 ORDER BY pr.fire_at LIMIT ${SEND_LIMIT}`,
  ).bind(now).all();
  for (const row of results) {
    await env.DB.prepare('UPDATE project_reminders SET sent = 1 WHERE project_id = ? AND fire_at = ?')
      .bind(row.project_id, row.fire_at).run();
    if (row.fire_at < now - STALE_MS) continue;
    const { results: open } = await env.DB.prepare(
      'SELECT assignee_id FROM project_tasks WHERE project_id = ? AND done_at IS NULL',
    ).bind(row.project_id).all();
    await notifyUsers(env, null, [row.leader_id, ...open.map((t) => t.assignee_id)], {
      kind: 'project_reminder',
      title: '프로젝트 리마인더',
      body: `${row.room_name}방 - ${row.project_name} · 남은 업무 ${open.length}개`,
      target: `project:${row.room_id}`,
    });
  }
}
