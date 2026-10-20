// 아맞다 서버 (Cloudflare Worker): 구글 로그인, 데이터 동기화, 텔레그램 알림봇
//
// 로그인 (auth.js)
// - GET  /auth/google/start?return=<앱 주소>  구글 로그인 시작
// - GET  /auth/google/callback                구글이 돌려보내는 주소
// - POST /auth/exchange                       일회용 코드 → 로그인 토큰
// - POST /auth/telegram                       텔레그램 미니앱 자동 로그인 (tg_login.js)
// - GET  /auth/me, POST /auth/logout          (로그인 필요)
// - /auth/pin...                              2차 비밀번호 (pin.js)
// 데이터 (로그인 필요, Authorization: Bearer <토큰>)
// - POST /api/sync                            바뀐 데이터 올리기·받기 (sync.js)
// - POST /api/telegram/code                   텔레그램 연결 코드 만들기 → t.me/<봇>?start=<코드>
// - GET/DELETE /api/telegram                  텔레그램 연결 확인·끊기 (tg_routes.js)
// - PUT  /api/telegram/nag                    끈질긴 알림 켜기·끄기
// - PUT  /api/reminders                       알림 일정 전체 올리기 (텔레그램·푸시 공용)
// - GET /api/push/key, POST·DELETE /api/push/subscribe   시스템 알림(Web Push) 구독 (push.js)
// - GET·PUT /api/profile                      닉네임#태그·사진·자기소개 (profile.js)
// - GET /api/notifications, POST /api/notifications/read   앱 알림함 (inbox.js)
// - /api/project-rooms..., /api/users/lookup   프로젝트방·팀원 초대 (project_rooms.js)
// - /api/projects..., /api/project-tasks...    프로젝트·세부업무, 완료 보고 (project_items.js)
//   팀장·팀원 권한은 project_db.js의 requireRoom이 요청마다 확인한다
// - GET/POST/DELETE /admin/allowed-emails     허용 이메일 관리 (관리자만, admin.js)
// - POST /api/reminders/ack                   끈질긴 알림 끄기 (앱의 [앱에서 보기]로 연 경우)
// 텔레그램
// - POST /telegram/webhook, GET /setup, GET /api/info
// - 1분마다(cron) 시각이 된 알림을 텔레그램(끈질긴 알림은 nag.js)과 푸시 구독 기기(push.js)로 보낸다
//
// 필요한 설정: 비밀값 BOT_TOKEN, GOOGLE_CLIENT_ID, GOOGLE_CLIENT_SECRET, ALLOWED_EMAILS, OWNER_EMAIL, PIN_PEPPER,
//            VAPID_PUBLIC_KEY, VAPID_PRIVATE_KEY, VAPID_SUBJECT (푸시, 없으면 푸시만 꺼짐)
//            D1 바인딩 DB, 변수 ALLOWED_ORIGINS(쉼표로 구분)

import { adminRoute } from './admin.js';
import { exchangeLogin, finishLogin, logout, publicUser, requireUser, startLogin } from './auth.js';
import { HttpError, cors, json, readJson, text } from './http.js';
import { inboxRoute } from './inbox.js';
import { disablePin, pinStatus, resetPin, sendResetCode, setPin, verifyPin } from './pin.js';
import { profileRoute } from './profile.js';
import { projectItemRoute } from './project_items.js';
import { projectRoomRoute } from './project_rooms.js';
import { pushRoute, sendDuePushes } from './push.js';
import { sync } from './sync.js';
import { botInfo, sendDueReminders, setup, webhook } from './telegram.js';
import { telegramLogin } from './tg_login.js';
import { telegramRoute } from './tg_routes.js';

export default {
  async fetch(request, env, ctx) {
    try {
      return await route(request, env, ctx);
    } catch (e) {
      if (e instanceof HttpError) return json({ error: e.message, ...e.extra }, e.status, request, env);
      console.error(e);
      return json({ error: '서버 오류' }, 500, request, env);
    }
  },

  async scheduled(_event, env, ctx) {
    // 무료 요금제의 외부 호출 한도를 넘지 않도록 텔레그램 → 푸시 순서로 차례대로 보낸다
    ctx.waitUntil(sendDueReminders(env).finally(() => sendDuePushes(env)));
  },
};

async function route(request, env, ctx) {
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
  if (path === '/auth/telegram' && method === 'POST') return reply(await telegramLogin(await readJson(request), env));


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
  const adminReply = await adminRoute(path, method, user, request, env, url);
  if (adminReply) return reply(adminReply);
  if (path === '/api/sync' && method === 'POST') return reply(await sync(user, await readJson(request), env));

  const tgReply = await telegramRoute(path, method, user, request, env);
  if (tgReply) return reply(...tgReply);
  const pushReply = await pushRoute(path, method, user, request, env);
  if (pushReply) return reply(...pushReply);
  const profileReply = await profileRoute(path, method, user, request, env);
  if (profileReply) return reply(...profileReply);
  const inboxReply = await inboxRoute(path, method, user, request, env, url);
  if (inboxReply) return reply(...inboxReply);
  const roomReply = await projectRoomRoute(path, method, user, request, env, url, ctx);
  if (roomReply) return reply(...roomReply);
  const itemReply = await projectItemRoute(path, method, user, request, env, ctx);
  if (itemReply) return reply(...itemReply);
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
