// 노션 API. 브라우저에서는 노션 API를 직접 부를 수 없어 서버가 대신 부른다.
// 토큰은 서버 비밀값(BOT_TOKEN)에서 만든 키로 암호화해 저장한다 (봇 토큰을 바꾸면 노션 토큰을 다시 넣어야 한다).
// 사용자가 고른 데이터베이스와 속성 매핑을 쓴다 (특정 DB·속성 이름에 묶이지 않는다).

import { base64url, hmacBytes } from './crypto.js';

const API = 'https://api.notion.com/v1';
const VERSION = '2022-06-28';

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

/** 노션 주소나 id에서 32자리 id를 뽑는다 ("https://notion.so/.../할일-3955ece3...?v=..." 도 된다) */
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

/** 데이터베이스 이름과 속성 목록 (앱의 매핑 드롭다운용). 선택·상태 속성은 고를 수 있는 값도 함께 */
export async function inspectDb(token, dbId) {
  const db = await notion(token, 'GET', `/databases/${dbId}`);
  const name = (db.title ?? []).map((t) => t.plain_text ?? t.text?.content ?? '').join('') || '이름 없는 데이터베이스';
  const properties = Object.entries(db.properties ?? {}).map(([prop, p]) => ({
    name: prop,
    type: p.type,
    ...(p.type === 'select' || p.type === 'status' ? { options: (p[p.type]?.options ?? []).map((o) => o.name) } : {}),
  }));
  return { name, properties };
}

const LABEL = { title: '제목', done: '완료', date: '날짜', content: '내용', status: '처음 상태' };
const TYPES = { title: ['title'], done: ['checkbox', 'select', 'status'], date: ['date'], content: ['rich_text'], status: ['select', 'status'] };

/** 앱이 보낸 매핑을 DB 속성과 맞춰 본다. 맞으면 저장할 모양(속성 종류 포함), 아니면 NotionError(400) */
export function checkMap(kind, map, { properties }) {
  const byName = Object.fromEntries(properties.map((p) => [p.name, p]));
  const fail = (msg) => { throw new NotionError(400, msg); };
  const prop = (field, name) => {
    if (name == null || name === '') return null;
    const p = byName[String(name)];
    if (!p) fail(`'${name}' 속성을 데이터베이스에서 찾을 수 없어요`);
    if (!TYPES[field].includes(p.type)) fail(`${LABEL[field]}에는 '${name}' 속성(${p.type})을 쓸 수 없어요`);
    return p;
  };
  const option = (p, value, label) => {
    if (!value) fail(`${LABEL[label]} 값을 골라 주세요`);
    if (p.type === 'status' && !p.options.includes(value)) fail(`'${p.name}'에 '${value}' 값이 없어요`);
    return String(value);
  };
  const title = prop('title', map?.title) ?? fail('제목으로 쓸 속성을 골라 주세요');
  const out = { title: title.name };
  if (prop('date', map?.date)) out.date = map.date;
  if (prop('content', map?.content)) out.content = map.content;
  if (kind === 'task') {
    const done = prop('done', map?.done?.prop);
    if (done) {
      out.done = { prop: done.name, type: done.type };
      if (done.type !== 'checkbox') {
        out.done.doneValue = option(done, map.done.doneValue, 'done');
        out.done.todoValue = option(done, map.done.todoValue, 'done');
      }
    }
  } else {
    const status = prop('status', map?.status?.prop);
    if (status) out.status = { prop: status.name, type: status.type, value: option(status, map.status.value, 'status') };
  }
  return out;
}
