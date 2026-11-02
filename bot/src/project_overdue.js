// 기한 지난 할 일
// - 세부업무 [미완료 처리]: 담당자가 개인 할일에서 처리하면(동기화) 프로젝트에도 미완료로 기록, 팀장에게 알림
// - 세부업무 마감이 지나면(1분마다) 팀장에게 한 번 알림 (담당자는 개인 할일의 기한 지남 알림으로 받는다)
// - 개인 할일의 기한 지남(앱이 올린 'due:' 알림 일정)은 텔레그램·푸시를 켜지 않았어도 알림함에 남긴다

import { recordReminders } from './inbox.js';
import { STALE_MS } from './logic.js';
import { notifyUsers } from './notify.js';
import { handleOf, touchRoom } from './project_db.js';
import { refreshMirrors } from './project_mirror.js';

/** 1분에 보내는 세부업무 기한 지남 알림 수 (무료 요금제 외부 호출 한도) */
const OVERDUE_LIMIT = 5;

/**
 * 기한 지남이 되는 시각. 시간 없이 날짜만 정한 마감(앱에서 그날 00:00으로 저장)은 그날이 끝날 때.
 * 서버는 사용자 시간대를 모르므로 한국 시간(UTC+9) 자정을 날짜만 정한 마감으로 본다.
 */
const OVERDUE_AT = `(CASE WHEN (t.due_at + 32400000) % 86400000 = 0 THEN t.due_at + 86400000 ELSE t.due_at END)`;

/** 담당자 [user]가 세부업무를 미완료 처리 → 프로젝트에 기록, 팀장에게 알림 */
export async function markMissed(env, ctx, task, user) {
  if (task.done_at || task.missed_at) return;
  const now = Date.now();
  await env.DB.batch([
    env.DB.prepare('UPDATE project_tasks SET missed_at = ?, review_at = NULL, updated_at = ? WHERE id = ?')
      .bind(now, now, task.id),
    touchRoom(env, task.room_id),
  ]);
  await refreshMirrors(env, 't.id = ?', task.id);
  const [room, me] = await Promise.all([
    env.DB.prepare('SELECT id, name, leader_id FROM project_rooms WHERE id = ?').bind(task.room_id).first(),
    env.DB.prepare('SELECT nickname, tag, name FROM users WHERE id = ?').bind(user.id).first(),
  ]);
  await notifyUsers(env, ctx, [room.leader_id], {
    kind: 'project_missed', title: '미완료 처리', target: `project:${room.id}`,
    body: `${handleOf(me)}님이 ${room.name}방 - ${task.title}을(를) 미완료 처리했어요`,
  }, user.id);
}

/** 마감이 지난 진행 중 세부업무를 팀장에게 한 번 알린다 (팀장 본인 업무는 개인 할일 알림으로 충분) */
export async function sendProjectOverdue(env) {
  const now = Date.now();
  const { results } = await env.DB.prepare(
    `SELECT t.id, t.title, t.assignee_id, r.id AS room_id, r.name AS room_name, r.leader_id,
            u.nickname, u.tag, u.name
     FROM project_tasks t JOIN project_rooms r ON r.id = t.room_id LEFT JOIN users u ON u.id = t.assignee_id
     WHERE ${OVERDUE_AT} <= ?1 AND ${OVERDUE_AT} >= ?2 AND t.done_at IS NULL AND t.missed_at IS NULL AND t.review_at IS NULL
       AND t.overdue_notified_at IS NULL AND t.assignee_id IS NOT NULL
     ORDER BY t.due_at LIMIT ${OVERDUE_LIMIT}`,
  ).bind(now, now - STALE_MS).all();
  for (const t of results) {
    await env.DB.prepare('UPDATE project_tasks SET overdue_notified_at = ? WHERE id = ?').bind(now, t.id).run();
    await notifyUsers(env, null, [t.leader_id], {
      kind: 'project_overdue', title: '기한 지남', target: `project:${t.room_id}`,
      body: `${t.room_name}방 - ${t.title} (담당 ${handleOf(t)})`,
    }, t.assignee_id);
  }
}

/** 개인 할일의 기한 지남 알림('due:')은 텔레그램·푸시가 없어도 알림함에 남긴다 (같은 알림은 한 번만) */
export async function recordOverdueInbox(env) {
  const now = Date.now();
  const { results } = await env.DB.prepare(
    `SELECT code, key, text, buttons FROM reminders
     WHERE key LIKE 'due:%' AND fire_at <= ?1 AND fire_at >= ?2 LIMIT 100`,
  ).bind(now, now - STALE_MS).all();
  await recordReminders(env, results, results);
}
