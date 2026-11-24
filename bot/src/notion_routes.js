// 노션 연동 설정
// - GET    /api/notion        { enabled, hasToken, memoDb }  (토큰은 돌려주지 않는다)
// - PUT    /api/notion        { enabled?, token?, memoDb? }  켤 때는 메모 DB를 확인하고 저장한다
// - POST   /api/notion/check  { token?, memoDb? }            [연결 확인] (안 보낸 값은 저장된 값으로)
// - DELETE /api/notion        연동 해제 (토큰·DB 지움)

import { HttpError, readJson } from './http.js';
import { NotionError, checkMemoDb, notionId, openToken, sealToken } from './notion.js';
import { syncNotionMemos } from './notion_memos.js';

const TOKEN_PATTERN = /^[A-Za-z0-9_-]{20,200}$/;

async function settings(env, userId) {
  return env.DB.prepare('SELECT notion_enabled, notion_token, notion_memo_db FROM users WHERE id = ?').bind(userId).first();
}

const view = (s) => ({ enabled: s.notion_enabled === 1, hasToken: !!s.notion_token, memoDb: s.notion_memo_db ?? null });

/** 입력값(없으면 저장된 값)으로 메모 DB를 확인한다 → { token, memoDb, statusType } */
async function verify(env, saved, body) {
  const token = body?.token ? String(body.token).trim() : await openToken(env, saved.notion_token);
  const memoDb = body?.memoDb ? notionId(body.memoDb) : saved.notion_memo_db;
  if (!token) throw new HttpError(400, '노션 통합 토큰을 입력해 주세요');
  if (!TOKEN_PATTERN.test(token)) throw new HttpError(400, '노션 통합 토큰 모양이 아니에요');
  if (!memoDb) throw new HttpError(400, '메모용 DB ID(또는 DB 주소)를 입력해 주세요');
  try {
    const { statusType } = await checkMemoDb(token, memoDb);
    return { token, memoDb, statusType };
  } catch (e) {
    if (!(e instanceof NotionError)) throw e;
    const message = e.status === 401 ? '토큰이 맞지 않아요. 노션 통합 토큰을 다시 확인해 주세요'
      : e.status === 404 ? 'DB를 찾을 수 없어요. DB 주소와, 그 DB의 [연결]에 통합을 추가했는지 확인해 주세요'
        : e.message;
    throw new HttpError(400, message);
  }
}

/** [path]가 노션 설정 API면 [응답 내용], 아니면 null */
export async function notionRoute(path, method, user, request, env, ctx) {
  if (path !== '/api/notion' && path !== '/api/notion/check') return null;
  const saved = await settings(env, user.id);
  if (path === '/api/notion/check') {
    if (method !== 'POST') return null;
    await verify(env, saved, await readJson(request));
    return [{ ok: true, message: '노션 메모 DB에 연결할 수 있어요' }];
  }
  if (method === 'GET') return [view(saved)];
  if (method === 'DELETE') {
    await env.DB.prepare(
      'UPDATE users SET notion_enabled = 0, notion_token = NULL, notion_memo_db = NULL, notion_status_type = NULL WHERE id = ?',
    ).bind(user.id).run();
    return [view({ notion_enabled: 0 })];
  }
  if (method !== 'PUT') return null;
  const body = await readJson(request);
  const enabled = body?.enabled ?? saved.notion_enabled === 1;
  if (enabled) {
    const { token, memoDb, statusType } = await verify(env, saved, body);
    await env.DB.prepare(
      'UPDATE users SET notion_enabled = 1, notion_token = ?, notion_memo_db = ?, notion_status_type = ? WHERE id = ?',
    ).bind(await sealToken(env, token), memoDb, statusType, user.id).run();
    // 켜기 전에 반영하지 못한 변경이 있으면 이어서 보낸다
    ctx?.waitUntil?.(syncNotionMemos(env, user.id).catch(() => {}));
  } else {
    const token = body?.token ? String(body.token).trim() : null;
    if (token && !TOKEN_PATTERN.test(token)) throw new HttpError(400, '노션 통합 토큰 모양이 아니에요');
    await env.DB.prepare(
      `UPDATE users SET notion_enabled = 0, notion_token = COALESCE(?, notion_token),
         notion_memo_db = COALESCE(?, notion_memo_db) WHERE id = ?`,
    ).bind(token && (await sealToken(env, token)), body?.memoDb ? notionId(body.memoDb) : null, user.id).run();
  }
  return [view(await settings(env, user.id))];
}
