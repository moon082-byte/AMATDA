// 세부업무 상태 흐름: 진행중 → (담당자 완료 보고) 검토중 → (팀장) 최종완료 / 반려하면 진행중
// - 검토 요청: 팀장에게 알림 (팀장이 자기 업무를 보고하면 바로 최종완료)
// - 최종완료: 담당자 개인 할일에서 지우고 담당자에게 알림 / 반려: 진행중으로, 담당자에게 알림
// - 개인 할일에서 체크(project.reviewRequested)해도 같은 흐름 (guardMirrors)

import { HttpError } from './http.js';
import { notifyUsers } from './notify.js';
import { handleOf, touchRoom } from './project_db.js';
import { JOINED, mirrorData, parse, refreshMirrors, removeMirror, taskIdOf } from './project_mirror.js';

const roomOf = (env, roomId) =>
  env.DB.prepare('SELECT id, name, leader_id FROM project_rooms WHERE id = ?').bind(roomId).first();
const nameOf = async (env, userId) =>
  handleOf(await env.DB.prepare('SELECT nickname, tag, name FROM users WHERE id = ?').bind(userId).first());

async function setReview(env, task, at) {
  await env.DB.batch([
    env.DB.prepare('UPDATE project_tasks SET review_at = ?, updated_at = ? WHERE id = ?').bind(at, Date.now(), task.id),
    touchRoom(env, task.room_id),
  ]);
  await refreshMirrors(env, 't.id = ?', task.id);
}

/** 담당자의 완료 보고 → 검토중 (팀장 본인 업무면 바로 최종완료) */
export async function requestReview(env, ctx, task, user) {
  if (task.done_at || task.review_at) return;
  const r = await roomOf(env, task.room_id);
  if (r.leader_id === user.id) return approveTask(env, ctx, task, user);
  await setReview(env, task, Date.now());
  await notifyUsers(env, ctx, [r.leader_id], {
    kind: 'project_review', title: '검토 요청', target: `project:${r.id}`,
    body: `${await nameOf(env, user.id)}님이 ${r.name}방 - ${task.title} 완료를 보고했어요`,
  }, user.id);
}

/** 담당자가 검토 요청을 취소 → 진행중 */
export async function cancelReview(env, task) {
  if (task.done_at || !task.review_at) return;
  await setReview(env, task, null);
}

/** 최종완료: 완료를 기록하고 담당자 개인 할일에서 지운다 (담당자에게 알림) */
export async function approveTask(env, ctx, task, actor) {
  if (task.done_at) return;
  const now = Date.now();
  await env.DB.batch([
    env.DB.prepare('UPDATE project_tasks SET done_at = ?, review_at = NULL, updated_at = ? WHERE id = ?')
      .bind(now, now, task.id),
    touchRoom(env, task.room_id),
  ]);
  await removeMirror(env, task.assignee_id, task.id);
  const r = await roomOf(env, task.room_id);
  await notifyUsers(env, ctx, [task.assignee_id], {
    kind: 'project_done', title: '최종완료', target: `project:${r.id}`, body: `${r.name}방 - ${task.title}`,
  }, actor.id);
}

/** 반려 → 진행중, 담당자에게 알림 */
export async function rejectTask(env, ctx, task, actor) {
  if (task.done_at || !task.review_at) throw new HttpError(409, '검토 요청된 업무가 아니에요');
  await setReview(env, task, null);
  const r = await roomOf(env, task.room_id);
  await notifyUsers(env, ctx, [task.assignee_id], {
    kind: 'project_rejected', title: '반려', target: `project:${r.id}`,
    body: `${r.name}방 - ${task.title} 다시 확인해 주세요`,
  }, actor.id);
}

/**
 * 동기화로 올라온 개인 할일 중 프로젝트 업무(pt_)를 검사한다 ([changes.tasks]를 고쳐 쓴다).
 * - 내 업무가 아니거나 없어진 업무: 버린다
 * - 잠긴 칸(제목·마감·상태): 프로젝트 값으로 되돌린다
 * - 검토 요청(project.reviewRequested)이 바뀌면 완료 보고·검토 취소로 처리 (예전 앱의 isDone 체크도 보고로)
 * - 진행 중 업무를 지우면: 지우지 않고 다시 내려보낸다
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
    const wantsReview = own.project?.reviewRequested === true || own.isDone === true;
    if (wantsReview && !t.review_at && !t.done_at) {
      await requestReview(env, ctx, t, user);
      if (t.leader_id === user.id) continue; // 팀장 본인 업무는 바로 최종완료되어 개인 할일에서 지워졌다
      t.review_at = Date.now();
    } else if (!wantsReview && t.review_at && !t.done_at) {
      await cancelReview(env, t);
      t.review_at = null;
    }
    keep.push({ ...row, data: JSON.stringify(mirrorData(t, own)) });
  }
  changes.tasks = keep;
  return resend;
}
