// 프로젝트방 공용: 권한 확인, 입력 검사, 목록·상세 읽기

import { randomToken } from './crypto.js';
import { HttpError } from './http.js';

export const ROOM_PAGE_SIZE = 10;

export const newId = (prefix) => `${prefix}_${randomToken(9)}`;

/** 화면에 보이는 이름: 닉네임#태그 (닉네임이 없으면 구글 이름) */
export const handleOf = (u) => (u?.nickname ? `${u.nickname}#${u.tag}` : u?.name || '이름 없음');

/** 글자 입력 검사: 앞뒤 공백 정리, [max]자 이하, [required]면 비어 있으면 안 됨 */
export function text(value, max, label, required = true) {
  const v = String(value ?? '').trim();
  if (required && !v) throw new HttpError(400, `${label}을(를) 입력해 주세요`);
  if ([...v].length > max) throw new HttpError(400, `${label}은(는) ${max}자까지 쓸 수 있어요`);
  return v;
}

/** 마감 시각 (epoch ms). 비우면 null */
export function dueAt(value) {
  if (value === null || value === undefined || value === '') return null;
  const n = Number(value);
  if (!Number.isFinite(n) || n < 0) throw new HttpError(400, '마감 시각이 잘못됐어요');
  return Math.floor(n);
}

/** 텔레그램 방 링크: 비우거나 http(s) 주소 */
export function linkUrl(value) {
  const v = text(value, 300, '텔레그램 방 링크', false);
  if (v && !/^https?:\/\/\S+$/i.test(v)) throw new HttpError(400, '텔레그램 방 링크는 https:// 로 시작해야 해요');
  return v;
}

export const membership = (env, roomId, userId) =>
  env.DB.prepare('SELECT role, status FROM project_members WHERE room_id = ? AND user_id = ?')
    .bind(roomId, userId).first();

/**
 * 방 접근 권한을 확인한다. 참여 중(active)이어야 하고, [leader]면 팀장이어야 한다.
 * [invited]면 초대만 받은 사람도 통과 (수락·거절, 미리 보기).
 */
export async function requireRoom(env, roomId, user, { leader = false, invited = false } = {}) {
  const m = await membership(env, roomId, user.id);
  if (!m || (m.status !== 'active' && !(invited && m.status === 'invited'))) {
    throw new HttpError(404, '프로젝트방을 찾을 수 없어요');
  }
  if (leader && m.role !== 'leader') throw new HttpError(403, '팀장만 할 수 있어요');
  return m;
}

/** 세부업무와 그 방의 내 권한 */
export async function requireTask(env, taskId, user, opts) {
  const task = await env.DB.prepare('SELECT * FROM project_tasks WHERE id = ?').bind(taskId).first();
  if (!task) throw new HttpError(404, '세부업무를 찾을 수 없어요');
  return { task, member: await requireRoom(env, task.room_id, user, opts) };
}

export async function requireProject(env, projectId, user, opts) {
  const project = await env.DB.prepare('SELECT * FROM projects WHERE id = ?').bind(projectId).first();
  if (!project) throw new HttpError(404, '프로젝트를 찾을 수 없어요');
  return { project, member: await requireRoom(env, project.room_id, user, opts) };
}

export const roomRow = (env, roomId) =>
  env.DB.prepare('SELECT * FROM project_rooms WHERE id = ?').bind(roomId).first();

const taskView = (t) => ({
  id: t.id, projectId: t.project_id, title: t.title, assigneeId: t.assignee_id,
  dueAt: t.due_at, doneAt: t.done_at,
});

/** 방 상세: 방 정보, 내 역할, 팀원(초대 중 포함), 프로젝트와 세부업무 */
export async function roomDetail(env, roomId, me) {
  const [room, { results: members }, { results: projects }, { results: tasks }] = await Promise.all([
    roomRow(env, roomId),
    env.DB.prepare(
      `SELECT m.user_id, m.role, m.status, u.nickname, u.tag, u.name FROM project_members m
       JOIN users u ON u.id = m.user_id WHERE m.room_id = ? ORDER BY m.role = 'leader' DESC, m.created_at`,
    ).bind(roomId).all(),
    env.DB.prepare('SELECT * FROM projects WHERE room_id = ? ORDER BY position, created_at').bind(roomId).all(),
    env.DB.prepare('SELECT * FROM project_tasks WHERE room_id = ? ORDER BY position, created_at').bind(roomId).all(),
  ]);
  return {
    room: { id: room.id, name: room.name, goal: room.goal, telegramUrl: room.telegram_url, leaderId: room.leader_id },
    me: { userId: me.id, role: me.role, status: me.status },
    members: members.map((m) => ({
      userId: m.user_id, role: m.role, status: m.status, nickname: m.nickname ?? '', tag: m.tag ?? '',
      handle: handleOf(m),
    })),
    projects: projects.map((p) => ({
      id: p.id, name: p.name, dueAt: p.due_at,
      tasks: tasks.filter((t) => t.project_id === p.id).map(taskView),
    })),
  };
}

/** 내가 참여 중인 방 목록 (최근 바뀐 순, 10개씩)과 받은 초대 */
export async function listRooms(env, userId, page) {
  const offset = (Math.max(1, page) - 1) * ROOM_PAGE_SIZE;
  const [{ results }, count, { results: invites }] = await Promise.all([
    env.DB.prepare(
      `SELECT r.id, r.name, r.goal, m.role,
         (SELECT COUNT(*) FROM project_members x WHERE x.room_id = r.id AND x.status = 'active') AS members,
         (SELECT COUNT(*) FROM project_tasks t WHERE t.room_id = r.id) AS total,
         (SELECT COUNT(*) FROM project_tasks t WHERE t.room_id = r.id AND t.done_at IS NOT NULL) AS done,
         (SELECT COUNT(*) FROM project_tasks t WHERE t.room_id = r.id AND t.assignee_id = ?1 AND t.done_at IS NULL) AS my_open
       FROM project_rooms r JOIN project_members m ON m.room_id = r.id AND m.user_id = ?1 AND m.status = 'active'
       ORDER BY r.updated_at DESC, r.id LIMIT ${ROOM_PAGE_SIZE} OFFSET ?2`,
    ).bind(userId, offset).all(),
    env.DB.prepare(`SELECT COUNT(*) AS n FROM project_members WHERE user_id = ? AND status = 'active'`).bind(userId).first(),
    env.DB.prepare(
      `SELECT r.id, r.name, u.nickname, u.tag, u.name AS uname FROM project_members m
       JOIN project_rooms r ON r.id = m.room_id LEFT JOIN users u ON u.id = m.invited_by
       WHERE m.user_id = ? AND m.status = 'invited' ORDER BY m.created_at DESC`,
    ).bind(userId).all(),
  ]);
  return {
    page: Math.max(1, page),
    pageSize: ROOM_PAGE_SIZE,
    total: count?.n ?? 0,
    rooms: results.map((r) => ({
      id: r.id, name: r.name, goal: r.goal, role: r.role, members: r.members,
      total: r.total, done: r.done, myOpen: r.my_open,
    })),
    invites: invites.map((i) => ({
      roomId: i.id, roomName: i.name, invitedBy: handleOf({ nickname: i.nickname, tag: i.tag, name: i.uname }),
    })),
  };
}

/** 방 내용이 바뀌었음을 기록 (목록 정렬용) */
export const touchRoom = (env, roomId) =>
  env.DB.prepare('UPDATE project_rooms SET updated_at = ? WHERE id = ?').bind(Date.now(), roomId);
