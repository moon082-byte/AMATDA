// 프로젝트 알림을 바로 보낸다: 앱 알림함 + 텔레그램(연결한 사람) + 시스템 알림(푸시 구독 기기)
// 리마인더(시각 예약)와 달리 일이 생긴 순간에 보내므로 cron을 거치지 않는다.

import { addNotifications } from './inbox.js';
import { pushConfigured, sendWebPush } from './webpush.js';

/** 받는 사람에게 열 앱 주소 (?open=project:<방>) */
export const openUrl = (env, target) =>
  env.APP_URL && target ? `${env.APP_URL}?open=${target}` : null;

async function deliver(env, userIds, msg) {
  for (const id of userIds) {
    await addNotifications(env, id, [{ kind: msg.kind, title: msg.title, body: msg.body, target: msg.target }]);
  }
  const marks = userIds.map(() => '?').join(',');
  const url = openUrl(env, msg.target);

  if (env.BOT_TOKEN) {
    const { results: links } = await env.DB.prepare(
      `SELECT DISTINCT chat_id FROM links WHERE user_id IN (${marks}) OR code IN (${marks})`,
    ).bind(...userIds, ...userIds).all();
    const text = [`📁 ${msg.title}`, msg.body].filter(Boolean).join('\n');
    for (const { chat_id } of links) {
      const payload = { chat_id, text };
      const withButton = url
        ? { ...payload, reply_markup: { inline_keyboard: [[{ text: '📱 앱에서 보기', url }]] } }
        : payload;
      const res = await fetch(`https://api.telegram.org/bot${env.BOT_TOKEN}/sendMessage`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(withButton),
      }).catch(() => null);
      if (res?.status === 400 && url) {
        await fetch(`https://api.telegram.org/bot${env.BOT_TOKEN}/sendMessage`, {
          method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload),
        }).catch(() => null);
      }
    }
  }

  if (pushConfigured(env)) {
    const { results: subs } = await env.DB.prepare(
      `SELECT endpoint, p256dh, auth FROM push_subscriptions WHERE user_id IN (${marks})`,
    ).bind(...userIds).all();
    for (const sub of subs) {
      const status = await sendWebPush(sub, { title: `📁 ${msg.title}`, body: msg.body, tag: msg.kind, url }, env)
        .catch(() => 0);
      if (status === 404 || status === 410) {
        await env.DB.prepare('DELETE FROM push_subscriptions WHERE endpoint = ?').bind(sub.endpoint).run();
      }
    }
  }
}

/**
 * [userIds]에게 알린다 (본인 [actorId]는 빼고). 응답을 늦추지 않도록 [ctx]가 있으면 뒤에서 보낸다.
 * msg: {kind, title, body, target}
 */
export async function notifyUsers(env, ctx, userIds, msg, actorId = null) {
  const ids = [...new Set(userIds.filter((id) => id && id !== actorId))];
  if (!ids.length) return;
  const work = deliver(env, ids, msg).catch((e) => console.error('프로젝트 알림 실패', e));
  if (ctx?.waitUntil) ctx.waitUntil(work);
  else await work;
}
