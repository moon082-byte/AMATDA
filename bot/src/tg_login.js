// 텔레그램 미니앱 자동 로그인
// 알림의 [앱에서 보기]는 텔레그램 안(미니앱)에서 열린다. 구글은 텔레그램 안 브라우저에서
// 로그인을 막으므로, 텔레그램이 서명해 넘겨주는 사용자 정보(initData)를 확인해
// 그 텔레그램 대화방에 연결된 계정으로 로그인한다. (https://core.telegram.org/bots/webapps)

import { isAllowedEmail } from './admin.js';
import { createSession, publicUser } from './auth.js';
import { hmacBytes, safeEqual } from './crypto.js';
import { HttpError } from './http.js';

export const INIT_DATA_MAX_AGE_MS = 60 * 60 * 1000; // 1시간이 지난 initData는 받지 않는다

const hex = (bytes) => [...bytes].map((b) => b.toString(16).padStart(2, '0')).join('');

/** initData 서명·유효시간 확인. 맞으면 텔레그램 사용자 번호, 아니면 null */
export async function verifyInitData(initData, botToken, now) {
  const params = new URLSearchParams(typeof initData === 'string' ? initData : '');
  const hash = params.get('hash');
  if (!hash || !botToken) return null;
  params.delete('hash');
  const check = [...params.entries()]
    .sort(([a], [b]) => (a < b ? -1 : a > b ? 1 : 0))
    .map(([k, v]) => `${k}=${v}`)
    .join('\n');
  const secret = await hmacBytes('WebAppData', botToken);
  if (!safeEqual(hex(await hmacBytes(secret, check)), hash)) return null;
  const authDate = Number(params.get('auth_date')) * 1000;
  if (!Number.isFinite(authDate) || now - authDate > INIT_DATA_MAX_AGE_MS) return null;
  try {
    const id = JSON.parse(params.get('user') ?? '').id;
    return Number.isSafeInteger(id) ? id : null;
  } catch {
    return null;
  }
}

/** POST /auth/telegram {initData} → 로그인 토큰 (봇과의 개인 대화방 번호 = 텔레그램 사용자 번호) */
export async function telegramLogin(body, env) {
  const tgId = await verifyInitData(body?.initData, env.BOT_TOKEN, Date.now());
  if (!tgId) throw new HttpError(401, '텔레그램 확인에 실패했어요. 알림의 버튼을 다시 눌러 주세요.');
  const user = await env.DB.prepare(
    `SELECT u.id, u.email, u.name, u.picture FROM links l JOIN users u ON u.id = l.user_id
     WHERE l.chat_id = ? ORDER BY l.created_at DESC LIMIT 1`,
  ).bind(tgId).first();
  if (!user) {
    throw new HttpError(404, '이 텔레그램과 연결된 계정이 없어요. 브라우저에서 로그인한 뒤 설정에서 텔레그램을 연결해 주세요.');
  }
  if (!(await isAllowedEmail(env, user.email))) {
    throw new HttpError(403, '허용되지 않은 계정이에요');
  }
  return { token: await createSession(env, user.id), user: publicUser(env, user) };
}
