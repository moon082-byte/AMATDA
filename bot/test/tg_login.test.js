import assert from 'node:assert/strict';
import { createHmac } from 'node:crypto';
import { test } from 'node:test';
import worker from '../src/index.js';
import { verifyInitData } from '../src/tg_login.js';
import { fakeD1 } from './support/d1.js';

const BOT_TOKEN = '123:test';

/** 텔레그램이 하는 방식 그대로 initData를 서명한다 (Node crypto로 따로 구현) */
function signInitData(fields, token = BOT_TOKEN) {
  const check = Object.keys(fields).sort().map((k) => `${k}=${fields[k]}`).join('\n');
  const secret = createHmac('sha256', 'WebAppData').update(token).digest();
  const hash = createHmac('sha256', secret).update(check).digest('hex');
  return new URLSearchParams({ ...fields, hash }).toString();
}
const fresh = (userId = 100, ageSec = 10) => signInitData({
  auth_date: String(Math.floor(Date.now() / 1000) - ageSec),
  query_id: 'AAE1',
  user: JSON.stringify({ id: userId, first_name: '문' }),
});

test('initData 서명·유효시간 확인', async () => {
  const now = Date.now();
  assert.equal(await verifyInitData(fresh(), BOT_TOKEN, now), 100);
  assert.equal(await verifyInitData(fresh(), '999:other', now), null, '다른 봇 토큰');
  assert.equal(await verifyInitData(fresh().replace('100', '200'), BOT_TOKEN, now), null, '내용을 바꾸면 서명이 깨진다');
  assert.equal(await verifyInitData(fresh(100, 2 * 60 * 60), BOT_TOKEN, now), null, '1시간이 지난 값');
  assert.equal(await verifyInitData('', BOT_TOKEN, now), null);
  assert.equal(await verifyInitData(undefined, BOT_TOKEN, now), null);
});

test('텔레그램 미니앱에서 열면 연결된 계정으로 로그인된다', async () => {
  const env = { DB: fakeD1(), BOT_TOKEN, ALLOWED_EMAILS: 'a@b.c', OWNER_EMAIL: '' };
  env.DB.exec(`INSERT INTO users (id, google_sub, email, created_at) VALUES ('u_1', 'g1', 'a@b.c', 0);
    INSERT INTO links (code, chat_id, chat_name, created_at, user_id) VALUES ('u_1', 100, '문', 0, 'u_1');`);
  const login = (initData) => worker.fetch(new Request('https://bot.test/auth/telegram', {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ initData }),
  }), env);

  const ok = await login(fresh());
  assert.equal(ok.status, 200);
  const { token, user } = await ok.json();
  assert.equal(user.id, 'u_1');
  const me = await worker.fetch(new Request('https://bot.test/auth/me', {
    headers: { Authorization: `Bearer ${token}` },
  }), env);
  assert.equal(me.status, 200, '발급한 토큰으로 로그인 상태가 된다');

  assert.equal((await login(fresh(555))).status, 404, '연결 안 된 텔레그램');
  assert.equal((await login('hash=abc')).status, 401, '서명이 틀림');
  env.ALLOWED_EMAILS = 'other@x.y';
  assert.equal((await login(fresh())).status, 403, '허용 목록 밖');
});
