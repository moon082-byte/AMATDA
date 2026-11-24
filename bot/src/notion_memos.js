// 메모 → 노션 1_Inbox 반영
// - 동기화로 메모가 바뀌면(노션 연동을 켠 계정) '반영할 것'으로 표시하고 바로 한 번, 실패하면 1분마다 다시 시도
// - 새 메모: 페이지 생성 (이름·내용 요약·상태=정리 대기, 본문=내용 전체) / 수정: 이름·내용·본문 갱신 / 삭제: 노션 휴지통으로
// - 결과는 메모 data.notion {pageId, syncedFor, error, errorFor}에 넣어 앱이 '노션 저장됨/실패'를 보여준다

import { NotionError, bodyBlocks, memoProperties, notion, openToken } from './notion.js';

/** 한 번에 처리하는 메모 수 (요청당 외부 호출 한도를 넘지 않게) */
export const NOTION_BATCH = 3;
/** 연속으로 이만큼 실패하면 다음 수정 때까지 다시 시도하지 않는다 */
export const NOTION_MAX_TRIES = 5;

/** 동기화로 올라온 메모들을 노션에 반영할 것으로 표시한다. 표시했으면 true */
export async function markMemosDirty(env, userId, memos) {
  if (!memos.length) return false;
  const res = await env.DB.prepare(
    `UPDATE memos SET notion_dirty = 1, notion_tries = 0
     WHERE user_id = ?1 AND id IN (SELECT value ->> 'id' FROM json_each(?2))
       AND EXISTS (SELECT 1 FROM users u WHERE u.id = ?1 AND u.notion_enabled = 1)`,
  ).bind(userId, JSON.stringify(memos)).run();
  return (res.meta?.changes ?? 0) > 0;
}

const bump = async (env, userId) =>
  (await env.DB.prepare('UPDATE users SET version = version + 1 WHERE id = ? RETURNING version').bind(userId).first()).version;

/** 처리 결과 저장. 그 사이 메모가 또 바뀌었으면(version이 다르면) 다음에 다시 반영한다 */
async function finish(env, row, { pageId, error = null }) {
  const data = JSON.parse(row.data);
  const notionInfo = error
    ? { ...(data.notion ?? {}), pageId, error, errorFor: data.updatedAt ?? null }
    : { pageId, syncedFor: data.updatedAt ?? null, error: null };
  const version = row.deleted ? null : await bump(env, row.user_id);
  await env.DB.prepare(
    `UPDATE memos SET notion_page_id = ?1,
       notion_tries = CASE WHEN ?2 IS NULL THEN 0 ELSE notion_tries + 1 END,
       notion_dirty = CASE WHEN ?2 IS NULL AND version = ?3 THEN 0 ELSE notion_dirty END,
       data = CASE WHEN ?4 IS NULL THEN data ELSE json_set(data, '$.notion', json(?5)) END,
       version = COALESCE(?4, version)
     WHERE user_id = ?6 AND id = ?7`,
  ).bind(pageId, error, row.version, version, JSON.stringify(notionInfo), row.user_id, row.id).run();
}

/** 노션 페이지 내용 바꾸기: 속성 갱신 → 본문 블록 지우고 새로 넣기 */
async function updatePage(token, pageId, memo, statusType) {
  await notion(token, 'PATCH', `/pages/${pageId}`, { properties: memoProperties(memo, { statusType, isNew: false }) });
  const { results = [] } = await notion(token, 'GET', `/blocks/${pageId}/children?page_size=100`);
  for (const b of results) await notion(token, 'DELETE', `/blocks/${b.id}`);
  const children = bodyBlocks(String(memo.content ?? ''));
  if (children.length) await notion(token, 'PATCH', `/blocks/${pageId}/children`, { children });
}

/** 노션에서 지웠거나 휴지통에 넣은 페이지라 새로 만들어야 하는 오류인지 */
const gone = (e) => e instanceof NotionError && (e.status === 404 || (e.status === 400 && /archiv|trash/i.test(e.message)));

/** 반영할 메모를 노션에 보낸다 ([userId]를 주면 그 계정만) */
export async function syncNotionMemos(env, userId = null) {
  const { results } = await env.DB.prepare(
    `SELECT m.user_id, m.id, m.data, m.deleted, m.version, m.notion_page_id,
            u.notion_token, u.notion_memo_db, u.notion_status_type
     FROM memos m JOIN users u ON u.id = m.user_id
     WHERE m.notion_dirty = 1 AND m.notion_tries < ${NOTION_MAX_TRIES} AND u.notion_enabled = 1
       AND (?1 IS NULL OR m.user_id = ?1)
     ORDER BY m.updated_at LIMIT ${NOTION_BATCH}`,
  ).bind(userId).all();
  for (const row of results) {
    const token = await openToken(env, row.notion_token);
    if (!token || !row.notion_memo_db) continue;
    let pageId = row.notion_page_id;
    try {
      if (row.deleted) {
        if (pageId) await notion(token, 'PATCH', `/pages/${pageId}`, { archived: true }).catch((e) => { if (!gone(e)) throw e; });
        await finish(env, row, { pageId: null });
        continue;
      }
      const memo = JSON.parse(row.data);
      const statusType = row.notion_status_type ?? 'select';
      if (pageId) {
        try {
          await updatePage(token, pageId, memo, statusType);
        } catch (e) {
          if (!gone(e)) throw e;
          pageId = null;
        }
      }
      if (!pageId) {
        const page = await notion(token, 'POST', '/pages', {
          parent: { database_id: row.notion_memo_db },
          properties: memoProperties(memo, { statusType, isNew: true }),
          children: bodyBlocks(String(memo.content ?? '')),
        });
        pageId = page.id;
      }
      await finish(env, row, { pageId });
    } catch (e) {
      console.error('노션 반영 실패', row.id, e.message);
      await finish(env, row, { pageId, error: String(e.message ?? e).slice(0, 200) });
    }
  }
}
