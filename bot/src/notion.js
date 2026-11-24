// 노션 API (메모 → 노션 1_Inbox). 브라우저에서는 노션 API를 직접 부를 수 없어 서버가 대신 부른다.
// 토큰은 서버 비밀값(BOT_TOKEN)에서 만든 키로 암호화해 저장한다 (봇 토큰을 바꾸면 노션 토큰을 다시 넣어야 한다).

import { base64url, hmacBytes } from './crypto.js';

const API = 'https://api.notion.com/v1';
const VERSION = '2022-06-28';
/** 노션 글 조각 하나의 최대 길이 */
const TEXT_MAX = 2000;
/** 노션 '내용' 속성에 넣는 요약 길이 */
export const SUMMARY_MAX = 200;

export class NotionError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

export async function notion(token, method, path, body) {
  const res = await fetch(`${API}${path}`, {
    method,
    headers: { Authorization: `Bearer ${token}`, 'Notion-Version': VERSION, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  });
  const json = await res.json().catch(() => ({}));
  if (!res.ok) throw new NotionError(res.status, json.message ?? `노션 오류 (${res.status})`);
  return json;
}

/** 노션 주소나 id에서 32자리 id를 뽑는다 ("https://notion.so/.../1_Inbox-3955ece3...?v=..." 도 된다) */
export function notionId(input) {
  const s = String(input ?? '').split('?')[0].replace(/-/g, '');
  const m = /([0-9a-f]{32})(?!.*[0-9a-f]{32})/i.exec(s);
  return m ? m[1].toLowerCase() : null;
}

const key = async (env) => crypto.subtle.importKey(
  'raw', await hmacBytes(`amatda-notion:${env.BOT_TOKEN}`, 'token-key'), 'AES-GCM', false, ['encrypt', 'decrypt']);

export async function sealToken(env, token) {
  const iv = crypto.getRandomValues(new Uint8Array(12));
  const data = new Uint8Array(await crypto.subtle.encrypt({ name: 'AES-GCM', iv }, await key(env), new TextEncoder().encode(token)));
  return `${base64url(iv)}.${base64url(data)}`;
}

export async function openToken(env, sealed) {
  if (!sealed) return null;
  try {
    const [iv, data] = sealed.split('.').map((p) => Uint8Array.from(atob(p.replace(/-/g, '+').replace(/_/g, '/')), (c) => c.charCodeAt(0)));
    return new TextDecoder().decode(await crypto.subtle.decrypt({ name: 'AES-GCM', iv }, await key(env), data));
  } catch {
    return null;
  }
}

/**
 * 메모 DB가 쓸 수 있는지 확인한다: 제목 속성(이름), '내용'(텍스트), '상태'(선택 또는 상태)
 * @returns {{ statusType: 'select'|'status' }}
 */
export async function checkMemoDb(token, dbId) {
  const db = await notion(token, 'GET', `/databases/${dbId}`);
  const props = db.properties ?? {};
  const missing = [];
  if (props['이름']?.type !== 'title') missing.push('이름(제목)');
  if (props['내용']?.type !== 'rich_text') missing.push('내용(텍스트)');
  if (!['select', 'status'].includes(props['상태']?.type)) missing.push('상태(선택)');
  if (missing.length) throw new NotionError(400, `메모 DB에 ${missing.join(', ')} 속성이 필요해요`);
  return { statusType: props['상태'].type };
}

const text = (s) => [{ type: 'text', text: { content: s } }];

/** 본문: 내용 전체를 2000자씩 나눈 문단들 (줄바꿈은 그대로) */
export function bodyBlocks(content) {
  const blocks = [];
  for (let i = 0; i < content.length; i += TEXT_MAX) {
    blocks.push({ object: 'block', type: 'paragraph', paragraph: { rich_text: text(content.slice(i, i + TEXT_MAX)) } });
  }
  return blocks.slice(0, 100);
}

/** 메모 → 노션 속성 (상태는 새로 만들 때만 '정리 대기', 수정할 때는 노션에서 바꾼 상태를 그대로 둔다) */
export function memoProperties(memo, { statusType, isNew }) {
  const content = String(memo.content ?? '');
  const title = String(memo.title ?? '').trim() || content.split('\n')[0].trim().slice(0, 100) || '제목 없음';
  const summary = content.length > SUMMARY_MAX ? `${content.slice(0, SUMMARY_MAX - 1)}…` : content;
  return {
    이름: { title: text(title) },
    내용: { rich_text: summary ? text(summary) : [] },
    ...(isNew ? { 상태: { [statusType]: { name: '정리 대기' } } } : {}),
  };
}
