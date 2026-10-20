// 프로필: 닉네임#태그, 프로필 사진, 자기소개
// - GET /api/profile   내 프로필 {nickname, tag, bio, avatar}  (nickname이 비어 있으면 앱이 첫 설정 화면을 띄운다)
// - PUT /api/profile   바꿀 것만 보낸다 {nickname?, bio?, avatar?}  avatar: data URL(200KB 이하) 또는 null(삭제)
// 태그: 처음 닉네임을 정할 때 그 닉네임에서 아직 안 쓴 4자리 번호를 무작위로 준다.
//       닉네임을 바꿔도 유지하되, 새 닉네임에서 같은 태그를 이미 다른 사람이 쓰면 새 번호를 준다(tagChanged).

import { HttpError, readJson, validate } from './http.js';

export const MAX_AVATAR = 280_000; // data URL 길이 (사진 약 200KB)
export const MAX_BIO = 150;
const NICKNAME = /^[\p{L}\p{N}_\-. ]{2,12}$/u;
const AVATAR = /^data:image\/(jpeg|png|webp);base64,[A-Za-z0-9+/]+=*$/;

/** 앱이 보낸 프로필 변경을 검사한다. 보내지 않은 항목은 undefined */
export function sanitizeProfile(body) {
  const out = {};
  if (body?.nickname !== undefined) {
    const nickname = String(body.nickname).trim().replace(/\s+/g, ' ');
    if (!NICKNAME.test(nickname)) throw new Error('닉네임은 2~12자의 글자·숫자로 정해 주세요 (# 은 쓸 수 없어요)');
    out.nickname = nickname;
  }
  if (body?.bio !== undefined) {
    const bio = String(body.bio ?? '').trim();
    if ([...bio].length > MAX_BIO) throw new Error(`자기소개는 ${MAX_BIO}자까지 쓸 수 있어요`);
    out.bio = bio;
  }
  if (body?.avatar !== undefined) {
    if (body.avatar === null) {
      out.avatar = null;
    } else {
      const avatar = String(body.avatar);
      if (avatar.length > MAX_AVATAR) throw new Error('사진 용량이 너무 커요 (200KB 이하)');
      if (!AVATAR.test(avatar)) throw new Error('사진 형식이 아니에요');
      out.avatar = avatar;
    }
  }
  return out;
}

/** [nickname]에서 다른 사람이 쓰지 않는 태그. 지금 태그([current])를 쓸 수 있으면 그대로 */
async function pickTag(env, userId, nickname, current) {
  const { results } = await env.DB.prepare(
    'SELECT tag FROM users WHERE lower(nickname) = lower(?) AND id != ?',
  ).bind(nickname, userId).all();
  const taken = new Set(results.map((r) => r.tag));
  if (current && !taken.has(current)) return current;
  if (taken.size >= 9000) throw new HttpError(409, '이 닉네임은 더 쓸 수 없어요. 다른 닉네임을 골라 주세요');
  for (;;) {
    const tag = String(1000 + (crypto.getRandomValues(new Uint32Array(1))[0] % 9000));
    if (!taken.has(tag)) return tag;
  }
}

const view = (u) => ({ nickname: u.nickname ?? '', tag: u.tag ?? '', bio: u.bio ?? '', avatar: u.avatar ?? null });

const load = (env, userId) =>
  env.DB.prepare('SELECT nickname, tag, bio, avatar FROM users WHERE id = ?').bind(userId).first();

/** [path]가 프로필 API면 [응답 내용], 아니면 null */
export async function profileRoute(path, method, user, request, env) {
  if (path !== '/api/profile') return null;
  if (method === 'GET') return [view(await load(env, user.id))];
  if (method !== 'PUT') return null;

  const raw = await readJson(request);
  const edits = validate(() => sanitizeProfile(raw));
  const before = await load(env, user.id);
  const next = { ...before, ...edits };
  let tagChanged = false;
  if (edits.nickname !== undefined) {
    next.tag = await pickTag(env, user.id, edits.nickname, before.tag);
    tagChanged = !!before.tag && next.tag !== before.tag;
  }
  if (!next.nickname) throw new HttpError(400, '닉네임을 먼저 정해 주세요');
  try {
    await env.DB.prepare(
      `UPDATE users SET nickname = ?2, tag = ?3, bio = ?4, avatar = ?5,
         avatar_updated_at = CASE WHEN ?6 THEN ?7 ELSE avatar_updated_at END WHERE id = ?1`,
    ).bind(user.id, next.nickname, next.tag, next.bio ?? '', next.avatar ?? null,
      edits.avatar !== undefined ? 1 : 0, Date.now()).run();
  } catch (e) {
    // 같은 순간 다른 사람이 같은 닉네임#태그를 가져간 경우 (고유 인덱스)
    if (/UNIQUE/i.test(String(e?.message))) throw new HttpError(409, '잠시 뒤 다시 저장해 주세요');
    throw e;
  }
  return [{ ...view(next), tagChanged }];
}
