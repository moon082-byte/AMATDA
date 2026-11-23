// 텔레그램 봇이 계정의 할 일·루틴을 읽고 바꾼다.
// 앱 동기화와 같은 표·같은 JSON 모양으로 저장하고 순번을 올리므로, 앱은 다음 동기화(30초 이내·앱을 열 때)에 받는다.

import { addNotifications } from './inbox.js';
import { appDate, formatDue, overdueAt, parseAppDate } from './kst.js';
import { SYNC_TABLES, STALE_MS } from './logic.js';
import { ackIdFor } from './nag.js';
import { saveChanges } from './sync.js';

/** 알림함에서 '이 기기' 대신 보이는 출처 (앱 기기 번호와 겹치지 않는다) */
const DEVICE = 'telegram_bot';
export const TABLE = { t: 'tasks', r: 'routines' };

/** 앱 id와 같은 모양의 무작위 꼬리 (예: task_1791296028315_k3x9) */
const suffix = () => Array.from(crypto.getRandomValues(new Uint8Array(4)), (b) => 'abcdefghijklmnopqrstuvwxyz0123456789'[b % 36]).join('');

const parse = (s) => {
  try {
    return JSON.parse(s);
  } catch {
    return null;
  }
};

/** 개인 대화방에 연결된 계정. 그룹방은 다른 사람이 내 일정을 보거나 바꿀 수 있어 쓰지 않는다 */
export async function chatAccount(env, chatId) {
  if (!(chatId > 0)) return null;
  return env.DB.prepare(
    'SELECT u.id FROM links l JOIN users u ON u.id = l.user_id WHERE l.chat_id = ? LIMIT 1',
  ).bind(chatId).first();
}

/** 지우지 않은 할 일·루틴 ({id, parentId, position, data, ...data, due}) */
export async function loadSchedule(env, userId) {
  const { results } = await env.DB.prepare(
    `SELECT 'tasks' AS tbl, id, parent_id, position, data FROM tasks WHERE user_id = ?1 AND deleted = 0
     UNION ALL SELECT 'routines', id, parent_id, position, data FROM routines WHERE user_id = ?1 AND deleted = 0`,
  ).bind(userId).all();
  const out = { tasks: [], routines: [] };
  for (const r of results) {
    const data = parse(r.data);
    if (!data) continue;
    out[r.tbl].push({ ...data, id: r.id, parentId: r.parent_id, position: r.position, data,
      due: parseAppDate(data.dueDate) });
  }
  out.tasks.sort((a, b) => a.position - b.position);
  return out;
}

/** 봇이 바꿀 수 있는 항목 (프로젝트에서 배정된 업무는 앱에서처럼 담당자가 바꿀 수 없다) */
export async function findItem(env, userId, kind, id) {
  const table = TABLE[kind];
  if (!table) return null;
  const row = await env.DB.prepare(`SELECT id, parent_id, position, data FROM ${table} WHERE user_id = ? AND id = ? AND deleted = 0`)
    .bind(userId, id).first();
  const data = row && parse(row.data);
  if (!data || (table === 'tasks' && (id.startsWith('pt_') || data.project))) return null;
  return { id, parentId: row.parent_id, position: row.position, data };
}

async function write(env, userId, changes, events) {
  const all = Object.fromEntries(SYNC_TABLES.map((t) => [t, changes[t] ?? []]));
  const total = Object.values(all).reduce((n, l) => n + l.length, 0);
  await saveChanges(env, userId, all, total);
  await addNotifications(env, userId, events.map((e) => ({ ...e, device: DEVICE })));
}

const row = (item, data, deleted = false) =>
  ({ id: item.id, parentId: item.parentId ?? null, position: item.position ?? 0, data: JSON.stringify(data), deleted });

/** 기한 지남 알림 일정을 바로 등록한다 (앱을 열지 않아도 알림이 가도록, 키는 앱이 만드는 것과 같다) */
async function scheduleDue(env, userId, id, title, dueAt) {
  const statements = [env.DB.prepare("DELETE FROM reminders WHERE code = ? AND key LIKE ? ESCAPE '\\'")
    .bind(userId, `due:${id.replace(/[%_\\]/g, '\\$&')}:%`)];
  const at = dueAt == null ? null : overdueAt(dueAt);
  if (at != null && at > Date.now() - STALE_MS) {
    const key = `due:${id}:${new Date(at).toISOString()}`;
    const buttons = env.APP_URL ? JSON.stringify([{ text: '📱 앱에서 보기', url: `${env.APP_URL}?open=task:${encodeURIComponent(id)}` }]) : null;
    statements.push(env.DB.prepare(
      `INSERT OR REPLACE INTO reminders (code, key, fire_at, due_at, text, buttons, ack_id) VALUES (?, ?, ?, ?, ?, ?, ?)`,
    ).bind(userId, key, at, at, `[기한 지남] ${title}\n[마감기한] ${formatDue(dueAt)}`, buttons, await ackIdFor(env, userId, key)));
  }
  await env.DB.batch(statements);
}

/** 할 일 추가 → 새 id */
export async function addTask(env, userId, { title, dueAt }) {
  const last = await env.DB.prepare('SELECT MAX(position) AS p FROM tasks WHERE user_id = ? AND deleted = 0').bind(userId).first();
  const now = Date.now();
  const item = { id: `task_${now}_${suffix()}`, parentId: null, position: (last?.p ?? -1) + 1 };
  const data = {
    title, description: null, isDone: false, dueDate: dueAt == null ? null : appDate(dueAt), completedAt: null,
    priority: 'medium', createdAt: appDate(now), remindAt: [],
  };
  await write(env, userId, { tasks: [row(item, data)] },
    [{ kind: 'task_added', title: '텔레그램에서 할 일 추가', body: title, target: `task:${item.id}` }]);
  await scheduleDue(env, userId, item.id, title, dueAt);
  return item.id;
}

/** 할 일 이름·마감 수정 (알림 시각은 그대로) */
export async function updateTask(env, userId, item, { title, dueAt }) {
  const data = { ...item.data, title, dueDate: dueAt == null ? null : appDate(dueAt) };
  await write(env, userId, { tasks: [row(item, data)] },
    [{ kind: 'task_edited', title: '텔레그램에서 할 일 수정', body: title, target: `task:${item.id}` }]);
  await scheduleDue(env, userId, item.id, title, dueAt);
}

/** 루틴 이름·요일·시각 수정 */
export async function updateRoutine(env, userId, item, { name, weekdays, hour, minute }) {
  const data = { ...item.data, name, weekdays, hour, minute };
  await write(env, userId, { routines: [row(item, data)] },
    [{ kind: 'routine_edited', title: '텔레그램에서 루틴 수정', body: name, target: `routine:${item.id}` }]);
}

/** 할 일(세부 항목·메모 포함) 또는 루틴을 지운다. 다른 기기에도 '삭제됨'으로 전달된다 */
export async function deleteItem(env, userId, kind, item) {
  const name = item.data.title ?? item.data.name ?? '';
  const changes = { [TABLE[kind]]: [row(item, item.data, true)] };
  if (kind === 't') {
    for (const table of ['sub_tasks', 'notes']) {
      const { results } = await env.DB.prepare(`SELECT id, parent_id, position, data FROM ${table} WHERE user_id = ? AND parent_id = ? AND deleted = 0`)
        .bind(userId, item.id).all();
      changes[table] = results.map((r) => ({ id: r.id, parentId: r.parent_id, position: r.position, data: r.data, deleted: true }));
    }
  }
  await write(env, userId, changes, [{
    kind: kind === 't' ? 'task_deleted' : 'routine_deleted',
    title: kind === 't' ? '텔레그램에서 할 일 삭제' : '텔레그램에서 루틴 삭제', body: name, target: null,
  }]);
  const prefixes = kind === 't' ? ['task', 'sub', 'due'] : ['routine'];
  const esc = item.id.replace(/[%_\\]/g, '\\$&');
  await env.DB.batch(prefixes.map((p) => env.DB.prepare("DELETE FROM reminders WHERE code = ? AND key LIKE ? ESCAPE '\\'")
    .bind(userId, `${p}:${esc}:%`)));
}
