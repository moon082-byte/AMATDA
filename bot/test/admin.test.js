import assert from 'node:assert/strict';
import { beforeEach, test } from 'node:test';
import { sha256Hex } from '../src/crypto.js';
import worker from '../src/index.js';
import { fakeD1 } from './support/d1.js';

let env;
const tokens = {};

async function addUser(id, email) {
  const token = `tok_${id}`.padEnd(40, 'x');
  tokens[id] = token;
  env.DB.exec(`INSERT INTO users (id, google_sub, email, created_at) VALUES ('${id}', 'g_${id}', '${email}', 0);
    INSERT INTO sessions (token_hash, user_id, created_at, last_used_at)
    VALUES ('${await sha256Hex(token)}', '${id}', ${Date.now()}, ${Date.now()});`);
}
const call = (id, method, path, body) => worker.fetch(new Request(`https://bot.test${path}`, {
  method,
  headers: { Authorization: `Bearer ${tokens[id]}`, 'Content-Type': 'application/json' },
  body: body ? JSON.stringify(body) : undefined,
}), env);

beforeEach(async () => {
  env = { DB: fakeD1(), ALLOWED_EMAILS: 'boss@x.com', OWNER_EMAIL: 'boss@x.com' };
  await addUser('u_boss', 'boss@x.com');
  await addUser('u_friend', 'friend@x.com');
});

test('관리자가 허용 이메일을 추가하면 그 사람이 쓸 수 있고, 지우면 바로 막힌다', async () => {
  assert.equal((await call('u_friend', 'GET', '/auth/me')).status, 403, '목록에 없으면 막힘');

  const added = await call('u_boss', 'POST', '/admin/allowed-emails', { email: ' Friend@X.com ' });
  assert.equal(added.status, 200);
  assert.deepEqual((await added.json()).emails.map((e) => [e.email, e.fixed]),
    [['boss@x.com', true], ['friend@x.com', false]]);
  assert.equal((await call('u_friend', 'GET', '/auth/me')).status, 200, '추가하면 바로 쓸 수 있다');

  const removed = await call('u_boss', 'DELETE', '/admin/allowed-emails?email=friend%40x.com');
  assert.deepEqual((await removed.json()).emails.map((e) => e.email), ['boss@x.com']);
  assert.equal((await call('u_friend', 'GET', '/auth/me')).status, 403, '지우면 다음 요청부터 막힘');
});

test('관리자만 쓸 수 있고, 서버 설정의 이메일은 지울 수 없고, 형식이 틀리면 거부', async () => {
  await call('u_boss', 'POST', '/admin/allowed-emails', { email: 'friend@x.com' });
  assert.equal((await call('u_friend', 'GET', '/admin/allowed-emails')).status, 403);
  assert.equal((await call('u_boss', 'DELETE', '/admin/allowed-emails?email=boss%40x.com')).status, 400);
  assert.equal((await call('u_boss', 'POST', '/admin/allowed-emails', { email: 'not-an-email' })).status, 400);
  const me = await (await call('u_boss', 'GET', '/auth/me')).json();
  assert.equal(me.user.owner, true);
});
