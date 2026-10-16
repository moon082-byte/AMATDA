import assert from 'node:assert/strict';
import { afterEach, beforeEach, test } from 'node:test';
import { base64url } from '../src/crypto.js';
import { replaceReminders, unlinkCodes } from '../src/db.js';
import { MAX_SUBSCRIPTIONS, pushMessage, pushRoute, sendDuePushes } from '../src/push.js';
import { telegramRoute } from '../src/tg_routes.js';
import { fakeD1 } from './support/d1.js';

let env;
let pushes;
let status;
const realFetch = globalThis.fetch;
const user = { id: 'u_1' };
const item = (key, fireIn = -1000) => ({
  key,
  fireAt: Date.now() + fireIn,
  dueAt: Date.now() + 60 * 60 * 1000,
  text: '[체크리스트 업무] 보고서\n[세부항목] 자료 취합\n[업무링크] https://notion.so/a',
  buttons: [{ text: '📱 앱에서 보기', url: 'https://app.test/?open=task:t1' }],
});
const req = (method, body) =>
  new Request('https://bot.test/api/push/subscribe', { method, body: JSON.stringify(body) });

/** 실제 브라우저처럼 P-256 공개키·16바이트 비밀값을 가진 구독 */
async function deviceSub(endpoint) {
  const pair = await crypto.subtle.generateKey({ name: 'ECDH', namedCurve: 'P-256' }, true, ['deriveBits']);
  const raw = new Uint8Array(await crypto.subtle.exportKey('raw', pair.publicKey));
  return { endpoint, keys: { p256dh: base64url(raw), auth: base64url(crypto.getRandomValues(new Uint8Array(16))) } };
}

beforeEach(async () => {
  const pair = await crypto.subtle.generateKey({ name: 'ECDSA', namedCurve: 'P-256' }, true, ['sign']);
  env = {
    DB: fakeD1(),
    VAPID_PUBLIC_KEY: base64url(new Uint8Array(await crypto.subtle.exportKey('raw', pair.publicKey))),
    VAPID_PRIVATE_KEY: (await crypto.subtle.exportKey('jwk', pair.privateKey)).d,
    VAPID_SUBJECT: 'mailto:a@b.c',
  };
  env.DB.exec(`INSERT INTO users (id, google_sub, email, created_at) VALUES ('u_1', 'g1', 'a@b.c', 0);`);
  pushes = [];
  status = 201;
  globalThis.fetch = async (url, init) => {
    pushes.push({ url: String(url), headers: init.headers });
    return new Response(null, { status });
  };
});
afterEach(() => {
  globalThis.fetch = realFetch;
});

test('구독 저장·갱신·삭제, 잘못된 키는 거절, 계정당 최대 개수 유지', async () => {
  assert.deepEqual(await pushRoute('/api/push/key', 'GET', user, null, env), [{ key: env.VAPID_PUBLIC_KEY }]);
  const sub = await deviceSub('https://push.test/a');
  await pushRoute('/api/push/subscribe', 'POST', user, req('POST', sub), env);
  await pushRoute('/api/push/subscribe', 'POST', user, req('POST', sub), env); // 같은 기기는 하나로
  assert.equal(env.DB.rows('SELECT * FROM push_subscriptions').length, 1);

  await assert.rejects(
    pushRoute('/api/push/subscribe', 'POST', user, req('POST', { ...sub, keys: { p256dh: 'AAAA', auth: 'x' } }), env),
    { status: 400 },
  );
  for (let i = 0; i < MAX_SUBSCRIPTIONS + 2; i++) {
    await pushRoute('/api/push/subscribe', 'POST', user, req('POST', await deviceSub(`https://push.test/${i}`)), env);
  }
  assert.equal(env.DB.rows('SELECT * FROM push_subscriptions').length, MAX_SUBSCRIPTIONS);

  await pushRoute('/api/push/subscribe', 'DELETE', user, req('DELETE', { endpoint: 'https://push.test/11' }), env);
  assert.equal(env.DB.rows('SELECT * FROM push_subscriptions').length, MAX_SUBSCRIPTIONS - 1);
});

test('텔레그램을 연결하지 않아도 알림 일정을 올릴 수 있다', async () => {
  const request = new Request('https://bot.test/api/reminders', {
    method: 'PUT', body: JSON.stringify({ reminders: [item('task:t1:a')] }),
  });
  const [body] = await telegramRoute('/api/reminders', 'PUT', user, request, env);
  assert.deepEqual(body, { ok: true, count: 1, linked: false });
});

test('시각이 된 알림을 모든 구독 기기로 한 번만 보내고, 만료된 구독은 지운다', async () => {
  for (const e of ['https://push.test/phone', 'https://push.test/pc']) {
    await pushRoute('/api/push/subscribe', 'POST', user, req('POST', await deviceSub(e)), env);
  }
  await replaceReminders(env, 'u_1', [item('task:t1:a'), item('task:t1:later', 60 * 60 * 1000)]);

  status = 410; // 두 기기 모두 만료
  await sendDuePushes(env);
  assert.equal(pushes.length, 2);
  assert.match(pushes[0].headers.Authorization, /^vapid t=.+, k=/);
  assert.equal(pushes[0].headers['Content-Encoding'], 'aes128gcm');
  assert.equal(env.DB.rows('SELECT * FROM push_subscriptions').length, 0);

  // 다시 구독하면, 이미 보낸 것으로 처리된 알림은 또 보내지 않는다
  await pushRoute('/api/push/subscribe', 'POST', user, req('POST', await deviceSub('https://push.test/new')), env);
  status = 201;
  pushes = [];
  await sendDuePushes(env);
  assert.equal(pushes.length, 0);
});

test('일시적인 오류면 다음에 다시 보내고, 일정을 다시 올려도 보낸 상태는 유지된다', async () => {
  await pushRoute('/api/push/subscribe', 'POST', user, req('POST', await deviceSub('https://push.test/a')), env);
  await replaceReminders(env, 'u_1', [item('task:t1:a')]);

  status = 503;
  await sendDuePushes(env);
  assert.equal(env.DB.rows('SELECT push_sent FROM reminders')[0].push_sent, 0);

  status = 201;
  await sendDuePushes(env);
  assert.equal(env.DB.rows('SELECT push_sent, sent FROM reminders')[0].push_sent, 1);
  await replaceReminders(env, 'u_1', [item('task:t1:a')]);
  assert.deepEqual({ ...env.DB.rows('SELECT push_sent, sent FROM reminders')[0] }, { push_sent: 1, sent: 0 });
  assert.equal(pushes.length, 2);
});

test('텔레그램 연결을 끊어도 푸시 구독이 있으면 알림 일정은 남긴다', async () => {
  await replaceReminders(env, 'u_1', [item('task:t1:a')]);
  await pushRoute('/api/push/subscribe', 'POST', user, req('POST', await deviceSub('https://push.test/a')), env);
  await unlinkCodes(env, ['u_1']);
  assert.equal(env.DB.rows('SELECT * FROM reminders').length, 1);
});

test('푸시 내용: 첫 줄은 제목, 업무링크 줄은 빼고, 누르면 할 일 화면 주소', () => {
  const row = { ...item('sub:t1:s1:x'), buttons: JSON.stringify(item('x').buttons) };
  assert.deepEqual(pushMessage(row), {
    title: '🔔 보고서',
    body: '[세부항목] 자료 취합',
    tag: 'sub:t1:s1:x',
    url: 'https://app.test/?open=task:t1',
  });
});
