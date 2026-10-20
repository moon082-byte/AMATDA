// 프로젝트방·팀원 API (로그인 필요)
// - GET    /api/project-rooms?page=N               내 방 목록(10개씩) + 받은 초대
// - POST   /api/project-rooms                      방 만들기 {name, goal, telegramUrl} → 만든 사람이 팀장
// - GET    /api/project-rooms/:id                  방 상세 (초대받은 사람도 미리 보기)
// - PUT    /api/project-rooms/:id                  방 수정 (팀장)
// - DELETE /api/project-rooms/:id                  방 삭제 (팀장)
// - GET    /api/users/lookup?handle=닉네임#1234     초대할 사람 찾기
// - POST   /api/project-rooms/:id/invites {userId} 초대 (팀장)
// - POST   /api/project-rooms/:id/accept | decline 초대 수락·거절 (초대받은 사람)
// - DELETE /api/project-rooms/:id/members/:userId  팀원 추방·초대 취소 (팀장)

import { HttpError, readJson } from './http.js';
import { notifyUsers } from './notify.js';
import {
  handleOf, linkUrl, listRooms, membership, newId, requireRoom, roomDetail, roomRow, text, touchRoom,
} from './project_db.js';

const roomFields = (raw) => ({
  name: text(raw?.name, 40, '방 이름'),
  goal: text(raw?.goal, 200, '목표', false),
  telegramUrl: linkUrl(raw?.telegramUrl),
});

/** 닉네임#태그로 사람 찾기 (대소문자 무시) */
async function lookup(env, handle) {
  const m = /^(.+)#(\d{4})$/.exec(String(handle ?? '').trim());
  if (!m) throw new HttpError(400, '닉네임#태그(예: 아맞다#1234) 형식으로 입력해 주세요');
  const u = await env.DB.prepare('SELECT id, nickname, tag FROM users WHERE lower(nickname) = lower(?) AND tag = ?')
    .bind(m[1].trim(), m[2]).first();
  if (!u) throw new HttpError(404, '그런 닉네임#태그를 가진 사람이 없어요');
  return { userId: u.id, nickname: u.nickname, tag: u.tag, handle: handleOf(u) };
}

export async function projectRoomRoute(path, method, user, request, env, url, ctx) {
  if (path === '/api/users/lookup' && method === 'GET') return [await lookup(env, url.searchParams.get('handle'))];

  if (path === '/api/project-rooms') {
    if (method === 'GET') return [await listRooms(env, user.id, Number(url.searchParams.get('page')) || 1)];
    if (method !== 'POST') return null;
    const f = roomFields(await readJson(request));
    const id = newId('prm');
    const now = Date.now();
    await env.DB.batch([
      env.DB.prepare(
        'INSERT INTO project_rooms (id, name, goal, telegram_url, leader_id, created_at, updated_at) VALUES (?, ?, ?, ?, ?, ?, ?)',
      ).bind(id, f.name, f.goal, f.telegramUrl, user.id, now, now),
      env.DB.prepare(
        `INSERT INTO project_members (room_id, user_id, role, status, created_at) VALUES (?, ?, 'leader', 'active', ?)`,
      ).bind(id, user.id, now),
    ]);
    return [await roomDetail(env, id, { id: user.id, role: 'leader', status: 'active' })];
  }

  const m = /^\/api\/project-rooms\/([A-Za-z0-9_-]+)(?:\/(invites|accept|decline|members)(?:\/([A-Za-z0-9_-]+))?)?$/.exec(path);
  if (!m) return null;
  const [, roomId, action, targetId] = m;

  if (!action) {
    if (method === 'GET') {
      const me = await requireRoom(env, roomId, user, { invited: true });
      return [await roomDetail(env, roomId, { id: user.id, ...me })];
    }
    if (method === 'PUT') {
      await requireRoom(env, roomId, user, { leader: true });
      const f = roomFields(await readJson(request));
      await env.DB.prepare('UPDATE project_rooms SET name = ?, goal = ?, telegram_url = ?, updated_at = ? WHERE id = ?')
        .bind(f.name, f.goal, f.telegramUrl, Date.now(), roomId).run();
      return [await roomDetail(env, roomId, { id: user.id, role: 'leader', status: 'active' })];
    }
    if (method === 'DELETE') {
      await requireRoom(env, roomId, user, { leader: true });
      await env.DB.batch(['project_tasks', 'projects', 'project_members'].map((t) =>
        env.DB.prepare(`DELETE FROM ${t} WHERE room_id = ?`).bind(roomId),
      ).concat(env.DB.prepare('DELETE FROM project_rooms WHERE id = ?').bind(roomId)));
      return [{ ok: true }];
    }
    return null;
  }

  if (action === 'invites' && method === 'POST') {
    await requireRoom(env, roomId, user, { leader: true });
    const raw = await readJson(request);
    const invitee = await env.DB.prepare('SELECT id, nickname FROM users WHERE id = ?').bind(String(raw?.userId ?? '')).first();
    if (!invitee?.nickname) throw new HttpError(404, '초대할 사람을 찾을 수 없어요');
    if (await membership(env, roomId, invitee.id)) throw new HttpError(409, '이미 팀원이거나 초대한 사람이에요');
    await env.DB.prepare(
      `INSERT INTO project_members (room_id, user_id, role, status, invited_by, created_at) VALUES (?, ?, 'member', 'invited', ?, ?)`,
    ).bind(roomId, invitee.id, user.id, Date.now()).run();
    const [room, me] = await Promise.all([roomRow(env, roomId), env.DB.prepare('SELECT nickname, tag, name FROM users WHERE id = ?').bind(user.id).first()]);
    await notifyUsers(env, ctx, [invitee.id], {
      kind: 'project_invite', title: '프로젝트 초대',
      body: `${handleOf(me)}님이 "${room.name}"방에 초대했어요`, target: `project:${roomId}`,
    });
    return [await roomDetail(env, roomId, { id: user.id, role: 'leader', status: 'active' })];
  }

  if ((action === 'accept' || action === 'decline') && method === 'POST') {
    const me = await requireRoom(env, roomId, user, { invited: true });
    if (me.status !== 'invited') throw new HttpError(409, '이미 참여 중이에요');
    await (action === 'accept'
      ? env.DB.prepare(`UPDATE project_members SET status = 'active' WHERE room_id = ? AND user_id = ?`)
      : env.DB.prepare('DELETE FROM project_members WHERE room_id = ? AND user_id = ?')
    ).bind(roomId, user.id).run();
    return [action === 'accept' ? await roomDetail(env, roomId, { id: user.id, role: 'member', status: 'active' }) : { ok: true }];
  }

  if (action === 'members' && targetId && method === 'DELETE') {
    await requireRoom(env, roomId, user, { leader: true });
    if (targetId === user.id) throw new HttpError(400, '팀장은 자신을 내보낼 수 없어요');
    // 내보낸 사람의 진행 중인 세부업무는 담당자 없음으로 돌린다
    await env.DB.batch([
      env.DB.prepare('DELETE FROM project_members WHERE room_id = ? AND user_id = ?').bind(roomId, targetId),
      env.DB.prepare('UPDATE project_tasks SET assignee_id = NULL WHERE room_id = ? AND assignee_id = ? AND done_at IS NULL')
        .bind(roomId, targetId),
      touchRoom(env, roomId),
    ]);
    return [await roomDetail(env, roomId, { id: user.id, role: 'leader', status: 'active' })];
  }
  return null;
}
