// 허용 이메일 (누가 로그인할 수 있는지)
// - 서버 비밀값 ALLOWED_EMAILS·OWNER_EMAIL: 항상 허용 (관리자가 잠기지 않게)
// - allowed_emails 표: 관리자(OWNER_EMAIL)가 앱의 설정 → 관리자 → 허용 이메일 관리에서 추가·삭제

import { HttpError, readJson } from './http.js';
import { parseEmails } from './logic.js';

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

/** 서버 설정(비밀값)에 있는 이메일 */
export const fixedEmails = (env) => new Set([...parseEmails(env.ALLOWED_EMAILS), ...parseEmails(env.OWNER_EMAIL)]);

export const isOwner = (env, email) => parseEmails(env.OWNER_EMAIL).has(String(email ?? '').toLowerCase());

/** 로그인할 수 있는 이메일인지. [inTable]을 이미 알면(로그인 확인 쿼리에서 함께 읽음) DB를 다시 읽지 않는다. */
export async function isAllowedEmail(env, email, inTable) {
  const e = String(email ?? '').toLowerCase();
  if (fixedEmails(env).has(e)) return true;
  if (inTable !== undefined) return !!inTable;
  return !!(await env.DB.prepare('SELECT 1 FROM allowed_emails WHERE email = ?').bind(e).first());
}

async function list(env) {
  const fixed = fixedEmails(env);
  const { results } = await env.DB.prepare('SELECT email, created_at FROM allowed_emails ORDER BY created_at').all();
  return {
    emails: [
      ...[...fixed].map((email) => ({ email, fixed: true })),
      ...results.filter((r) => !fixed.has(r.email)).map((r) => ({ email: r.email, fixed: false, addedAt: r.created_at })),
    ],
  };
}

/** /admin/allowed-emails: 관리자만 (PIN을 켰다면 확인한 뒤에만 여기까지 온다) */
export async function adminRoute(path, method, user, request, env, url) {
  if (path !== '/admin/allowed-emails') return null;
  if (!isOwner(env, user.email)) throw new HttpError(403, '관리자만 쓸 수 있어요');
  if (method === 'GET') return list(env);
  if (method === 'POST') {
    const raw = await readJson(request);
    const email = String(raw?.email ?? '').trim().toLowerCase();
    if (email.length > 254 || !EMAIL_PATTERN.test(email)) throw new HttpError(400, '이메일 형식이 아니에요');
    await env.DB.prepare('INSERT OR IGNORE INTO allowed_emails (email, added_by, created_at) VALUES (?, ?, ?)')
      .bind(email, user.id, Date.now()).run();
    return list(env);
  }
  if (method === 'DELETE') {
    const email = String(url.searchParams.get('email') ?? '').toLowerCase();
    if (fixedEmails(env).has(email)) throw new HttpError(400, '서버 설정에 있는 이메일은 여기서 지울 수 없어요');
    await env.DB.prepare('DELETE FROM allowed_emails WHERE email = ?').bind(email).run();
    return list(env);
  }
  throw new HttpError(405, '지원하지 않는 요청이에요');
}
