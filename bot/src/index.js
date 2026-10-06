// 아맞다 서버 (Cloudflare Worker): 구글 로그인, 데이터 동기화, 텔레그램 알림봇
//
// 로그인 (auth.js)
// - GET  /auth/google/start?return=<앱 주소>  구글 로그인 시작
// - GET  /auth/google/callback                구글이 돌려보내는 주소
// - POST /auth/exchange                       일회용 코드 → 로그인 토큰
// - GET  /auth/me, POST /auth/logout          (로그인 필요)
// - /auth/pin...                              2차 비밀번호 (pin.js)
// 데이터 (로그인 필요, Authorization: Bearer <토큰>)
// - POST /api/sync                            바뀐 데이터 올리기·받기 (sync.js)
// - POST /api/telegram/code                   텔레그램 연결 코드 만들기 → t.me/<봇>?start=<코드>
// - GET/DELETE /api/telegram                  텔레그램 연결 확인·끊기
// - PUT  /api/reminders                       알림 일정 전체 올리기
// 텔레그램
// - POST /telegram/webhook, GET /setup, GET /api/info
// - 1분마다(cron) 시각이 된 알림을 텔레그램으로 보낸다
// 예전 앱 호환 (로그인 전환이 끝나면 지운다): GET/DELETE /api/link/:code, PUT /api/reminders/:code
//
// 필요한 설정: 비밀값 BOT_TOKEN, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, ALLOWED_EMAILS, OWNER_EMAIL, PIN_PEPPER
//            D1 바인딩 DB, 변수 ALLOWED_ORIGINS(쉼표로 구분)

import { exchangeLogin, finishLogin, logout, publicUser, requireUser, startLogin } from './auth.js';
import { getLink, putState, replaceReminders, unlinkCodes } from './db.js';
import { HttpError, cors, json, readJson, text, validate } from './http.js';
import { CODE_PATTERN, sanitizeReminders } from './logic.js';
import { randomToken } from './crypto.js';
import { disablePin, pinStatus, resetPin, sendResetCode, setPin, verifyPin } from './pin.js';
import { sync } from './sync.js';
import { botInfo, sendDueReminders, setup, webhook } from './telegram.js';

const TG_CODE_TTL = 30 * 60 * 1000;

export default {
  async fetch(request, env) {
    try {
      return await route(request, env);
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.message, ...e.extra }, e.status, request, env);
      console.error(e);
      return json({ error: '서버 오류' }, 500, request, env);
    }
  },

  async scheduled(_event, env, ctx) {
    ctx.waitUntil(sendDueReminders(env));
  },
};

async function route(request, env) {
  const url = new URL(request.url);
  const path = url.pathname.replace(/\/+$/, '') || '/';
  const method = request.method;
  const reply = (body, status = 200) => json(body, status, request, env);
  if (method === 'OPTIONS') return cors(new Response(null, { status: 204 }), request, env);

  if (path === '/') return text('아맞다 서버가 동작 중이에요');
  if (path === '/setup' && method === 'GET') return setup(url, env);
  if (path === '/api/info' && method === 'GET') return reply(await botInfo(env));
  if (path === '/telegram/webhook' && method === 'POST') return webhook(request, env);

  if (path === '/auth/google/start' && method === 'GET') return startLogin(url, env);
  if (path === '/auth/google/callback' && method === 'GET') return finishLogin(url, env);
  if (path === '/auth/exchange' && method === 'POST') return reply(await exchangeLogin(await readJson(request), env));

  const legacy = /^\/api\/(link|reminders)\/([^/]+)$/.exec(path);
  if (legacy) return legacyRoute(legacy[1], legacy[2], request, env, reply);

  // ---- 여기부터는 로그인 필요 ----
  const user = await requireUser(request, env);
  if (path === '/auth/me' && method === 'GET') return reply({ user: publicUser(env, user) });
  if (path === '/auth/logout' && method === 'POST') {
    await logout(user, env);
    return reply({ ok: true });
  }
  if (path.startsWith('/auth/pin')) return reply(await pinRoute(path, method, user, request, env));

  // ---- PIN을 켠 계정은 이 로그인에서 PIN을 확인해야 데이터에 접근할 수 있다 ----
  if (user.pin_hash && !user.pin_ok_at) {
    const e = new HttpError(423, 'PIN 확인이 필요해요');
    e.extra = { pinRequired: true };
    throw e;
  }
  if (path === '/api/sync' && method === 'POST') return reply(await sync(user, await readJson(request), env));

  if (path === '/api/telegram/code' && method === 'POST') {
    const code = randomToken(24);
    await putState(env, { state: code, kind: 'tg', userId: user.id, ttlMs: TG_CODE_TTL });
    return reply({ code });
  }
  if (path === '/api/telegram' && method === 'GET') {
    const link = await getLink(env, user.id);
    return reply({ linked: !!link, name: link?.chat_name ?? null });
  }
  if (path === '/api/telegram' && method === 'DELETE') {
    await unlinkCodes(env, [user.id]);
    return reply({ linked: false });
  }
  if (path === '/api/reminders' && method === 'PUT') {
    if (!(await getLink(env, user.id))) return reply({ linked: false }, 404);
    const raw = await readJson(request);
    const items = validate(() => sanitizeReminders(raw));
    await replaceReminders(env, user.id, items);
    return reply({ ok: true, count: items.length });
  }
  return reply({ error: '없는 주소예요' }, 404);
}

async function pinRoute(path, method, user, request, env) {
  if (!env.PIN_PEPPER) throw new HttpError(503, 'PIN 설정(PIN_PEPPER)이 아직 없어요');
  const body = method === 'GET' || path === '/auth/pin/reset/send' ? null : await readJson(request);
  if (path === '/auth/pin' && method === 'GET') return pinStatus(user, env);
  if (path === '/auth/pin' && method === 'PUT') return setPin(user, body, env);
  if (path === '/auth/pin' && method === 'DELETE') return disablePin(user, body, env);
  if (path === '/auth/pin/verify' && method === 'POST') return verifyPin(user, body, env);
  if (path === '/auth/pin/reset/send' && method === 'POST') return sendResetCode(user, env);
  if (path === '/auth/pin/reset' && method === 'POST') return resetPin(user, body, env);
  throw new HttpError(404, '없는 주소예요');
}

/** 예전 앱(로그인 전)용 연결 코드 API. 계정 연결(user_id 있음)은 건드리지 못한다. */
async function legacyRoute(kind, code, request, env, reply) {
  if (!CODE_PATTERN.test(code) || code.startsWith('u_')) return reply({ error: '잘못된 연결 코드예요' }, 400);
  const link = await getLink(env, code);
  const mine = link && link.user_id == null ? link : null;
  if (kind === 'link' && request.method === 'GET') return reply({ linked: !!mine, name: mine?.chat_name ?? null });
  if (kind === 'link' && request.method === 'DELETE') {
    if (mine) await unlinkCodes(env, [code]);
    return reply({ linked: false });
  }
  if (kind === 'reminders' && request.method === 'PUT') {
    if (!mine) return reply({ linked: false }, 404);
    const raw = await readJson(request);
    const items = validate(() => sanitizeReminders(raw));
    await replaceReminders(env, code, items);
    return reply({ ok: true, count: items.length });
  }
  return reply({ error: '지원하지 않는 요청이에요' }, 405);
}
