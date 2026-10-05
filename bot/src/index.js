// 아맞다 텔레그램 알림봇 (Cloudflare Worker)
//
// - POST /telegram/webhook   텔레그램이 보내는 메시지 (/start <코드>, /stop, /status)
// - GET  /setup              이 서버 주소로 텔레그램 웹훅·명령어 목록을 등록 (여러 번 호출해도 안전)
// - GET  /api/info           봇 아이디·이름 확인
// - GET  /api/link/:code     앱이 연결 여부 확인
// - DELETE /api/link/:code   앱에서 연결 끊기
// - PUT  /api/reminders/:code 앱이 알림 일정 전체를 올림 (기존 일정은 교체)
// - 1분마다(cron) 시각이 된 알림을 텔레그램으로 보낸다
//
// 필요한 설정: 비밀값 BOT_TOKEN, D1 바인딩 DB, 변수 ALLOWED_ORIGINS(쉼표로 구분)

import { getLink, replaceReminders, unlinkCodes } from './db.js';
import { CODE_PATTERN, sanitizeReminders } from './logic.js';
import { botInfo, sendDueReminders, setup, webhook } from './telegram.js';

export default {
  async fetch(request, env) {
    try {
      return await route(request, env);
    } catch (e) {
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
  if (request.method === 'OPTIONS') return cors(new Response(null, { status: 204 }), request, env);

  if (path === '/') return new Response('아맞다 알림봇이 동작 중이에요');
  if (path === '/setup' && request.method === 'GET') return setup(url, env);
  if (path === '/api/info' && request.method === 'GET') return json(await botInfo(env), 200, request, env);
  if (path === '/telegram/webhook' && request.method === 'POST') return webhook(request, env);

  const m = /^\/api\/(link|reminders)\/([^/]+)$/.exec(path);
  if (!m) return json({ error: '없는 주소예요' }, 404, request, env);
  const [, kind, code] = m;
  if (!CODE_PATTERN.test(code)) return json({ error: '잘못된 연결 코드예요' }, 400, request, env);

  if (kind === 'link' && request.method === 'GET') {
    const link = await getLink(env, code);
    return json({ linked: !!link, name: link?.chat_name ?? null }, 200, request, env);
  }
  if (kind === 'link' && request.method === 'DELETE') {
    await unlinkCodes(env, [code]);
    return json({ linked: false }, 200, request, env);
  }
  if (kind === 'reminders' && request.method === 'PUT') {
    if (!(await getLink(env, code))) return json({ linked: false }, 404, request, env);
    const items = sanitizeReminders(await request.json());
    await replaceReminders(env, code, items);
    return json({ ok: true, count: items.length }, 200, request, env);
  }
  return json({ error: '지원하지 않는 요청이에요' }, 405, request, env);
}

// ---- HTTP ----

function json(body, status, request, env) {
  return cors(new Response(JSON.stringify(body), {
    status,
    headers: { 'Content-Type': 'application/json; charset=utf-8' },
  }), request, env);
}

/** 앱 주소(GitHub Pages)와 로컬 개발 주소에서만 호출할 수 있게 한다 */
function cors(response, request, env) {
  const origin = request.headers.get('Origin') ?? '';
  const allowed = (env.ALLOWED_ORIGINS ?? '').split(',').map((s) => s.trim()).filter(Boolean);
  if (allowed.includes(origin) || /^http:\/\/localhost(:\d+)?$/.test(origin)) {
    response.headers.set('Access-Control-Allow-Origin', origin);
    response.headers.set('Access-Control-Allow-Methods', 'GET, PUT, DELETE, OPTIONS');
    response.headers.set('Access-Control-Allow-Headers', 'Content-Type');
    response.headers.set('Vary', 'Origin');
  }
  return response;
}
