// 2차 비밀번호(4자리 PIN) — 계정 단위, 모든 기기 공통
//
// - GET    /auth/pin               PIN 사용 여부·잠금 상태
// - POST   /auth/pin/verify        {pin}            PIN 확인 (이 로그인 세션의 데이터 접근 허용)
// - PUT    /auth/pin               {pin, current?}  PIN 켜기·바꾸기 (켜져 있으면 현재 PIN 필요)
// - DELETE /auth/pin               {current}        PIN 끄기
// - POST   /auth/pin/reset/send                      텔레그램으로 6자리 재설정 코드 보내기
// - POST   /auth/pin/reset         {pin, code?}     코드(또는 구글로 막 로그인한 세션)로 새 PIN 정하기
//
// 연속 5번 틀리면 처음엔 1분, 그 뒤로는 30분 잠근다. 맞게 입력하면 횟수·잠금 단계가 처음으로 돌아간다.
// PIN이 켜진 계정은 이 로그인에서 PIN을 확인하기 전까지 데이터 API가 423으로 거부된다(index.js).

import { hmacHex, randomDigits, randomToken, safeEqual } from './crypto.js';
import { getLink } from './db.js';
import { HttpError } from './http.js';
import {
  FRESH_LOGIN_MS, PIN_PATTERN, PIN_RESET_MAX_TRIES, PIN_RESET_TTL, PIN_MAX_TRIES, nextPinState,
} from './logic.js';
import { tg } from './telegram.js';

const pinHash = (env, salt, pin) => hmacHex(env.PIN_PEPPER, `${salt}:${pin}`);

async function load(env, userId) {
  return env.DB.prepare(
    `SELECT pin_hash, pin_salt, pin_failed, pin_locked_until, pin_lock_level,
            pin_reset_hash, pin_reset_expires, pin_reset_tries FROM users WHERE id = ?`,
  ).bind(userId).first();
}

export async function pinStatus(user, env) {
  const u = await load(env, user.id);
  const now = Date.now();
  return {
    enabled: !!u.pin_hash,
    verified: !!user.pin_ok_at,
    lockedUntil: u.pin_locked_until > now ? u.pin_locked_until : null,
    remaining: PIN_MAX_TRIES - u.pin_failed,
    telegram: !!(await getLink(env, user.id)),
    freshLogin: now - user.session_created_at < FRESH_LOGIN_MS,
  };
}

/** 현재 PIN이 맞는지 확인하고 실패 횟수·잠금을 기록한다. 틀리거나 잠겨 있으면 예외 */
async function check(env, user, pin) {
  const u = await load(env, user.id);
  if (!u.pin_hash) throw new HttpError(409, 'PIN을 사용하지 않는 계정이에요');
  const now = Date.now();
  if (u.pin_locked_until > now) throw locked(u.pin_locked_until);
  const ok = PIN_PATTERN.test(String(pin ?? '')) && safeEqual(await pinHash(env, u.pin_salt, pin), u.pin_hash);
  const next = nextPinState(
    { failed: u.pin_failed, lockedUntil: u.pin_locked_until, level: u.pin_lock_level }, ok, now);
  await env.DB.prepare(
    'UPDATE users SET pin_failed = ?, pin_locked_until = ?, pin_lock_level = ? WHERE id = ?',
  ).bind(next.failed, next.lockedUntil, next.level, user.id).run();
  if (next.lockedUntil > now) throw locked(next.lockedUntil);
  if (!ok) {
    const e = new HttpError(400, 'PIN이 맞지 않아요');
    e.extra = { remaining: PIN_MAX_TRIES - next.failed };
    throw e;
  }
}

function locked(until) {
  const e = new HttpError(423, '잘못 입력해서 잠겼어요');
  e.extra = { lockedUntil: until };
  return e;
}

/** 이 세션은 PIN 확인 완료, 다른 기기는 (새) PIN을 다시 입력하게 한다 */
async function markVerified(env, user, othersToo) {
  const now = Date.now();
  await env.DB.batch([
    env.DB.prepare('UPDATE sessions SET pin_ok_at = ? WHERE token_hash = ?').bind(now, user.sessionHash),
    ...(othersToo ? [env.DB.prepare('UPDATE sessions SET pin_ok_at = NULL WHERE user_id = ? AND token_hash != ?')
      .bind(user.id, user.sessionHash)] : []),
  ]);
}

async function savePin(env, user, pin) {
  if (!PIN_PATTERN.test(String(pin ?? ''))) throw new HttpError(400, 'PIN은 숫자 4자리예요');
  const salt = randomToken(16);
  await env.DB.prepare(
    `UPDATE users SET pin_hash = ?, pin_salt = ?, pin_failed = 0, pin_locked_until = 0, pin_lock_level = 0,
            pin_reset_hash = NULL, pin_reset_expires = 0, pin_reset_tries = 0 WHERE id = ?`,
  ).bind(await pinHash(env, salt, pin), salt, user.id).run();
  await markVerified(env, user, true);
}

export async function verifyPin(user, body, env) {
  await check(env, user, body?.pin);
  await markVerified(env, user, false);
  return { ok: true };
}

export async function setPin(user, body, env) {
  const u = await load(env, user.id);
  if (u.pin_hash) await check(env, user, body?.current);
  await savePin(env, user, body?.pin);
  return { ok: true, enabled: true };
}

export async function disablePin(user, body, env) {
  await check(env, user, body?.current);
  await env.DB.prepare(
    `UPDATE users SET pin_hash = NULL, pin_salt = NULL, pin_failed = 0, pin_locked_until = 0,
            pin_lock_level = 0, pin_reset_hash = NULL, pin_reset_expires = 0 WHERE id = ?`,
  ).bind(user.id).run();
  return { ok: true, enabled: false };
}

export async function sendResetCode(user, env) {
  const link = await getLink(env, user.id);
  if (!link) throw new HttpError(409, '연결된 텔레그램이 없어요');
  const u = await load(env, user.id);
  const now = Date.now();
  if (u.pin_reset_expires - PIN_RESET_TTL > now - 60 * 1000) {
    throw new HttpError(429, '코드는 1분에 한 번만 보낼 수 있어요');
  }
  const code = randomDigits(6);
  await env.DB.prepare(
    'UPDATE users SET pin_reset_hash = ?, pin_reset_expires = ?, pin_reset_tries = 0 WHERE id = ?',
  ).bind(await pinHash(env, user.id, code), now + PIN_RESET_TTL, user.id).run();
  const sent = await tg(env, 'sendMessage', {
    chat_id: link.chat_id,
    text: `🔐 아맞다 PIN 재설정 코드: ${code}\n\n10분 동안 쓸 수 있어요. 직접 요청하지 않았다면 이 메시지를 무시해 주세요.`,
  });
  if (!sent.ok) throw new HttpError(502, '텔레그램으로 보내지 못했어요');
  return { ok: true };
}

export async function resetPin(user, body, env) {
  const fresh = Date.now() - user.session_created_at < FRESH_LOGIN_MS;
  if (body?.code != null || !fresh) {
    const u = await load(env, user.id);
    const valid = u.pin_reset_hash && u.pin_reset_expires > Date.now() && u.pin_reset_tries < PIN_RESET_MAX_TRIES;
    const ok = valid && safeEqual(await pinHash(env, user.id, String(body?.code ?? '')), u.pin_reset_hash);
    if (!ok) {
      if (valid) {
        await env.DB.prepare('UPDATE users SET pin_reset_tries = pin_reset_tries + 1 WHERE id = ?').bind(user.id).run();
      }
      throw new HttpError(400, valid ? '재설정 코드가 맞지 않아요' : '재설정 코드가 만료됐어요. 다시 받아 주세요');
    }
  }
  await savePin(env, user, body?.pin);
  return { ok: true, enabled: true };
}
