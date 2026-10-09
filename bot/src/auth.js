// 구글 로그인(OAuth 2.0 + PKCE)과 로그인 세션
//
// 1. 앱 → GET /auth/google/start?return=<앱 주소>  : 구글 로그인 화면으로 보낸다
// 2. 구글 → GET /auth/google/callback              : 코드를 토큰으로 바꾸고, 허용 목록 확인 후
//    <앱 주소>?login=<일회용 코드> 로 돌려보낸다 (실패하면 ?login_error=<이유>)
// 3. 앱 → POST /auth/exchange {code}               : 일회용 코드를 로그인 토큰으로 바꾼다
// 4. 이후 앱은 Authorization: Bearer <토큰> 으로 데이터 API를 부른다
//
// 쿠키 대신 토큰을 쓰는 이유: 앱(github.io)과 서버(workers.dev) 주소가 달라
// 브라우저의 제3자 쿠키 차단에 걸리기 때문이다.

import { pkceChallenge, randomToken, sha256Hex } from './crypto.js';
import { putState, takeState } from './db.js';
import { HttpError, redirect, text } from './http.js';
import { SESSION_IDLE_MS, checkIdClaims, decodeJwtPayload, parseEmails, safeReturnTo } from './logic.js';

const GOOGLE_AUTH = 'https://accounts.google.com/o/oauth2/v2/auth';
const GOOGLE_TOKEN = 'https://oauth2.googleapis.com/token';
const STATE_TTL = 10 * 60 * 1000;
const LOGIN_CODE_TTL = 2 * 60 * 1000;

const callbackUrl = (url) => `${url.origin}/auth/google/callback`;

export async function startLogin(url, env) {
  const returnTo = safeReturnTo(url.searchParams.get('return') ?? '', env.ALLOWED_ORIGINS);
  if (!returnTo) return text('허용되지 않은 앱 주소예요', 400);
  if (!env.GOOGLE_CLIENT_ID || !env.GOOGLE_CLIENT_SECRET) {
    return text('구글 로그인 설정(GOOGLE_CLIENT_ID / GOOGLE_CLIENT_SECRET)이 아직 없어요', 503);
  }
  const state = randomToken(24);
  const verifier = randomToken(48);
  await putState(env, { state, kind: 'state', verifier, returnTo, ttlMs: STATE_TTL });
  const params = new URLSearchParams({
    client_id: env.GOOGLE_CLIENT_ID,
    redirect_uri: callbackUrl(url),
    response_type: 'code',
    scope: 'openid email profile',
    state,
    code_challenge: await pkceChallenge(verifier),
    code_challenge_method: 'S256',
    prompt: 'select_account',
  });
  return redirect(`${GOOGLE_AUTH}?${params}`);
}

export async function finishLogin(url, env) {
  const row = await takeState(env, url.searchParams.get('state') ?? '', 'state');
  if (!row) return text('로그인 요청이 만료됐어요. 앱에서 다시 로그인해 주세요.', 400);
  const back = (params) => redirect(`${row.return_to}?${new URLSearchParams(params)}`);

  const code = url.searchParams.get('code');
  if (!code) return back({ login_error: 'cancelled' });
  const res = await fetch(GOOGLE_TOKEN, {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      code,
      client_id: env.GOOGLE_CLIENT_ID,
      client_secret: env.GOOGLE_CLIENT_SECRET,
      redirect_uri: callbackUrl(url),
      grant_type: 'authorization_code',
      code_verifier: row.verifier,
    }),
  });
  const token = await res.json().catch(() => ({}));
  if (!res.ok || !token.id_token) {
    console.error('구글 토큰 교환 실패', res.status, token.error);
    return back({ login_error: 'google' });
  }
  const claims = decodeJwtPayload(token.id_token);
  const problem = checkIdClaims(claims, env.GOOGLE_CLIENT_ID, Date.now());
  if (problem) {
    console.error('ID 토큰 확인 실패:', problem);
    return back({ login_error: 'google' });
  }

  const email = String(claims.email).toLowerCase();
  if (!parseEmails(env.ALLOWED_EMAILS).has(email)) return back({ login_error: 'not_allowed' });
  const userId = await upsertUser(env, claims, email);

  const loginCode = randomToken(24);
  await putState(env, { state: loginCode, kind: 'login', userId, ttlMs: LOGIN_CODE_TTL });
  return back({ login: loginCode });
}

/** 일회용 코드 → 로그인 토큰 */
export async function exchangeLogin(body, env) {
  const row = await takeState(env, typeof body?.code === 'string' ? body.code : '', 'login');
  if (!row) throw new HttpError(401, '로그인 코드가 만료됐어요. 다시 로그인해 주세요.');
  const token = await createSession(env, row.user_id);
  const user = await env.DB.prepare('SELECT id, email, name, picture FROM users WHERE id = ?')
    .bind(row.user_id).first();
  return { token, user: publicUser(env, user) };
}

/** 새 로그인 세션을 만들고 토큰을 돌려준다 (DB에는 토큰의 해시만 저장) */
export async function createSession(env, userId) {
  const token = randomToken(32);
  const now = Date.now();
  await env.DB.prepare(
    'INSERT INTO sessions (token_hash, user_id, created_at, last_used_at) VALUES (?, ?, ?, ?)',
  ).bind(await sha256Hex(token), userId, now, now).run();
  return token;
}

/** Authorization 헤더의 토큰으로 사용자를 찾는다. 없거나 만료·허용 목록 밖이면 401/403 */
export async function requireUser(request, env) {
  const m = /^Bearer ([A-Za-z0-9_-]{20,100})$/.exec(request.headers.get('Authorization') ?? '');
  if (!m) throw new HttpError(401, '로그인이 필요해요');
  const hash = await sha256Hex(m[1]);
  const row = await env.DB.prepare(
    `SELECT s.last_used_at, s.created_at AS session_created_at, s.pin_ok_at,
            u.id, u.email, u.name, u.picture, u.pin_hash
     FROM sessions s JOIN users u ON u.id = s.user_id WHERE s.token_hash = ?`,
  ).bind(hash).first();
  const now = Date.now();
  if (!row || row.last_used_at < now - SESSION_IDLE_MS) throw new HttpError(401, '로그인이 만료됐어요');
  if (!parseEmails(env.ALLOWED_EMAILS).has(row.email.toLowerCase())) {
    throw new HttpError(403, '허용되지 않은 계정이에요');
  }
  if (now - row.last_used_at > 60 * 60 * 1000) {
    await env.DB.prepare('UPDATE sessions SET last_used_at = ? WHERE token_hash = ?').bind(now, hash).run();
  }
  return { ...row, sessionHash: hash };
}

export async function logout(user, env) {
  await env.DB.prepare('DELETE FROM sessions WHERE token_hash = ?').bind(user.sessionHash).run();
}

/** 앱에 보여줄 사용자 정보. owner면 예전 기기 데이터를 가져올 수 있다. */
export function publicUser(env, u) {
  return {
    id: u.id,
    email: u.email,
    name: u.name ?? '',
    picture: u.picture ?? '',
    owner: parseEmails(env.OWNER_EMAIL).has(u.email.toLowerCase()),
  };
}

async function upsertUser(env, claims, email) {
  const found = await env.DB.prepare('SELECT id FROM users WHERE google_sub = ?').bind(claims.sub).first();
  if (found) {
    await env.DB.prepare('UPDATE users SET email = ?, name = ?, picture = ? WHERE id = ?')
      .bind(email, claims.name ?? null, claims.picture ?? null, found.id).run();
    return found.id;
  }
  const id = `u_${randomToken(12)}`;
  await env.DB.prepare(
    'INSERT INTO users (id, google_sub, email, name, picture, version, created_at) VALUES (?, ?, ?, ?, ?, 0, ?)',
  ).bind(id, claims.sub, email, claims.name ?? null, claims.picture ?? null, Date.now()).run();
  return id;
}
