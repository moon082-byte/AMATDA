// 앱 알림함
// - GET  /api/notifications?device=<기기>   최신순 50개와 안 읽은 개수 (그 기기가 올린 변경은 빼고)
// - POST /api/notifications/read            읽음 처리 {ids: [...]} 또는 {all: true, device}
// 쌓는 것: 다른 기기에서 바꾼 할 일(동기화 때, sync.js), 보낸 리마인더(텔레그램·푸시를 보낼 때)

import { randomToken } from './crypto.js';
import { readJson } from './http.js';
import { pushMessage } from './push.js';

export const KEEP_COUNT = 200;
export const KEEP_MS = 60 * 24 * 60 * 60 * 1000;
/** 한 번의 동기화에서 이보다 많이 바뀌면 알림 하나로 묶는다 (예: 데이터 가져오기) */
export const SUMMARY_OVER = 5;
const DEVICE_PATTERN = /^[A-Za-z0-9_-]{8,64}$/;

export const cleanDevice = (v) => (typeof v === 'string' && DEVICE_PATTERN.test(v) ? v : null);

const parse = (data) => {
  try {
    return JSON.parse(data);
  } catch {
    return null;
  }
};

/** 할 일 행 하나의 변경을 알림 종류·제목으로 바꾼다. 알릴 만한 변경이 아니면 null */
export function describeTaskChange(prev, next) {
  const before = prev && !prev.deleted ? parse(prev.data) : null;
  if (next.deleted) return before ? { kind: 'task_deleted', title: '할 일 삭제', name: before.title, target: null } : null;
  const after = parse(next.data);
  if (!after) return null;
  const target = `task:${next.id}`;
  if (!before) return { kind: 'task_added', title: '할 일 추가', name: after.title, target };
  if (!before.isDone && after.isDone) return { kind: 'task_done', title: '할 일 완료', name: after.title, target };
  if (before.isDone && !after.isDone) return { kind: 'task_reopened', title: '완료 취소', name: after.title, target };
  const same = (k) => JSON.stringify(before[k] ?? null) === JSON.stringify(after[k] ?? null);
  if (!same('title') || !same('dueDate') || !same('remindAt')) {
    return { kind: 'task_edited', title: '할 일 수정', name: after.title, target };
  }
  return null;
}

/** 알림을 넣고 오래된 것을 정리한다 */
export async function addNotifications(env, userId, items, now = Date.now()) {
  if (!items.length) return;
  await env.DB.batch([
    env.DB.prepare(
      `INSERT OR IGNORE INTO notifications (id, user_id, kind, title, body, target, device, created_at)
       SELECT j.value ->> 'id', ?1, j.value ->> 'kind', j.value ->> 'title', j.value ->> 'body',
              j.value ->> 'target', j.value ->> 'device', ?2
       FROM json_each(?3) AS j`,
    ).bind(userId, now, JSON.stringify(items.map((i) => ({ id: randomToken(12), ...i })))),
    env.DB.prepare(
      `DELETE FROM notifications WHERE user_id = ?1 AND (created_at < ?2 OR id NOT IN
         (SELECT id FROM notifications WHERE user_id = ?1 ORDER BY created_at DESC, rowid DESC LIMIT ${KEEP_COUNT}))`,
    ).bind(userId, now - KEEP_MS),
  ]);
}

/** 동기화로 올라온 할 일 변경을 알림으로 남긴다 ([device]가 올린 것은 그 기기에서는 안 보인다) */
export async function recordTaskChanges(env, userId, device, tasks) {
  if (!device || !tasks.length) return;
  const { results } = await env.DB.prepare(
    `SELECT id, data, deleted FROM tasks
     WHERE user_id = ?1 AND id IN (SELECT value ->> 'id' FROM json_each(?2))`,
  ).bind(userId, JSON.stringify(tasks)).all();
  const prev = new Map(results.map((r) => [r.id, r]));
  const events = tasks.map((t) => describeTaskChange(prev.get(t.id), t)).filter(Boolean);
  if (!events.length) return;
  const items = events.length > SUMMARY_OVER
    ? [{
        kind: 'tasks_changed',
        title: `다른 기기에서 할 일 ${events.length}개가 바뀌었어요`,
        body: events.slice(0, 3).map((e) => e.name).join(', ') + (events.length > 3 ? ' 외' : ''),
        target: null,
        device,
      }]
    : events.map((e) => ({ kind: e.kind, title: e.title, body: e.name, target: e.target, device }));
  await addNotifications(env, userId, items);
}

/**
 * 보낸 리마인더([rows] 중 [done]에 든 것)를 알림함에 남긴다.
 * 텔레그램·푸시 둘 다 보내도 같은 id라 한 번만 남고, 계정 연결(code = users.id)만 남긴다.
 */
export async function recordReminders(env, candidates, done) {
  const sent = new Set(done.map((d) => `${d.code} ${d.key}`));
  const rows = candidates.filter((r) => sent.has(`${r.code} ${r.key}`));
  if (!rows.length) return;
  const items = rows.map((r) => {
    const m = pushMessage(r);
    const target = /[?&]open=((?:task|routine|room):[^&]+)/.exec(m.url ?? '')?.[1] ?? null;
    return { id: `rem:${r.code}:${r.key}`.slice(0, 300), user: r.code, title: m.title, body: m.body,
      target: target && decodeURIComponent(target) };
  });
  await env.DB.prepare(
    `INSERT OR IGNORE INTO notifications (id, user_id, kind, title, body, target, created_at)
     SELECT j.value ->> 'id', j.value ->> 'user', 'reminder', j.value ->> 'title', j.value ->> 'body',
            j.value ->> 'target', ?2
     FROM json_each(?1) AS j WHERE EXISTS (SELECT 1 FROM users u WHERE u.id = j.value ->> 'user')`,
  ).bind(JSON.stringify(items), Date.now()).run();
}

/** [path]가 알림함 API면 [응답 내용], 아니면 null */
export async function inboxRoute(path, method, user, request, env, url) {
  if (path === '/api/notifications' && method === 'GET') {
    const device = cleanDevice(url.searchParams.get('device'));
    const mine = 'user_id = ?1 AND (device IS NULL OR device != ?2)';
    const [{ results }, unread] = await Promise.all([
      env.DB.prepare(
        `SELECT id, kind, title, body, target, created_at, read_at FROM notifications
         WHERE ${mine} ORDER BY created_at DESC, rowid DESC LIMIT 50`,
      ).bind(user.id, device ?? '').all(),
      env.DB.prepare(`SELECT COUNT(*) AS n FROM notifications WHERE ${mine} AND read_at IS NULL`)
        .bind(user.id, device ?? '').first(),
    ]);
    return [{
      unread: unread?.n ?? 0,
      items: results.map((r) => ({
        id: r.id, kind: r.kind, title: r.title, body: r.body ?? '', target: r.target,
        createdAt: r.created_at, read: r.read_at != null,
      })),
    }];
  }
  if (path === '/api/notifications/read' && method === 'POST') {
    const raw = await readJson(request);
    const now = Date.now();
    if (raw?.all === true) {
      await env.DB.prepare(
        `UPDATE notifications SET read_at = ?3 WHERE user_id = ?1 AND (device IS NULL OR device != ?2) AND read_at IS NULL`,
      ).bind(user.id, cleanDevice(raw.device) ?? '', now).run();
    } else {
      const ids = Array.isArray(raw?.ids) ? raw.ids.filter((i) => typeof i === 'string').slice(0, 100) : [];
      await env.DB.prepare(
        `UPDATE notifications SET read_at = ?3
         WHERE user_id = ?1 AND read_at IS NULL AND id IN (SELECT value FROM json_each(?2))`,
      ).bind(user.id, JSON.stringify(ids), now).run();
    }
    return [{ ok: true }];
  }
  return null;
}
