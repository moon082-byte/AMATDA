import assert from 'node:assert/strict';
import { test } from 'node:test';
import { pkceChallenge, randomToken } from '../src/crypto.js';
import {
  MAX_SYNC_ROWS, checkIdClaims, decodeJwtPayload, parseEmails, safeReturnTo, sanitizeSyncChanges,
} from '../src/logic.js';

const ORIGINS = 'https://moon082-byte.github.io';

test('로그인 후 돌아갈 주소는 앱 주소·localhost만 허용', () => {
  assert.equal(safeReturnTo('https://moon082-byte.github.io/AMATDA/?x=1#/', ORIGINS),
    'https://moon082-byte.github.io/AMATDA/');
  assert.equal(safeReturnTo('http://localhost:8765/', ORIGINS), 'http://localhost:8765/');
  assert.equal(safeReturnTo('https://evil.example/AMATDA/', ORIGINS), null);
  assert.equal(safeReturnTo('https://moon082-byte.github.io.evil.example/', ORIGINS), null);
  assert.equal(safeReturnTo('javascript:alert(1)', ORIGINS), null);
  assert.equal(safeReturnTo('', ORIGINS), null);
});

test('허용 이메일 목록은 대소문자·공백을 무시', () => {
  const set = parseEmails(' A@Gmail.com, b@x.com ,');
  assert.ok(set.has('a@gmail.com'));
  assert.ok(set.has('b@x.com'));
  assert.equal(set.size, 2);
  assert.equal(parseEmails(undefined).size, 0);
});

test('구글 ID 토큰 내용 확인', () => {
  const payload = { aud: 'cid', iss: 'https://accounts.google.com', sub: '1', email: 'a@b.c', email_verified: true, exp: 2e9 };
  const jwt = `x.${Buffer.from(JSON.stringify({ ...payload, name: '문다니엘' })).toString('base64url')}.y`;
  const claims = decodeJwtPayload(jwt);
  assert.equal(claims.name, '문다니엘');
  assert.equal(checkIdClaims(claims, 'cid', Date.now()), null);
  assert.ok(checkIdClaims(claims, 'other', Date.now()));
  assert.ok(checkIdClaims({ ...claims, email_verified: false }, 'cid', Date.now()));
  assert.ok(checkIdClaims({ ...claims, exp: 1 }, 'cid', Date.now()));
  assert.ok(checkIdClaims({ ...claims, iss: 'evil' }, 'cid', Date.now()));
});

test('동기화 변경 검사: 잘못된 항목은 버리고 개수 제한', () => {
  const { since, changes, total } = sanitizeSyncChanges({
    since: 5,
    changes: {
      tasks: [
        { id: 't1', parentId: 'room_1', position: 2, data: '{"title":"a"}' },
        { id: 't1', data: '{}' }, // 중복
        { id: 'bad id!', data: '{}' },
        { id: 't2', data: { title: 'b' }, deleted: true },
        { id: 't3', data: 'x'.repeat(20001) },
      ],
      notes: [{ id: 'n1', parentId: '../x', data: '{}' }],
    },
  });
  assert.equal(since, 5);
  assert.equal(total, 3);
  assert.deepEqual(changes.tasks.map((r) => r.id), ['t1', 't2']);
  assert.equal(changes.tasks[1].data, '{"title":"b"}');
  assert.equal(changes.tasks[1].deleted, 1);
  assert.equal(changes.notes[0].parentId, null);
  assert.deepEqual(changes.rooms, []);

  assert.throws(() => sanitizeSyncChanges({ since: -1 }));
  assert.throws(() => sanitizeSyncChanges({ changes: { tasks: 'x' } }));
  const many = Array.from({ length: MAX_SYNC_ROWS + 1 }, (_, i) => ({ id: `r${i}`, data: '{}' }));
  assert.throws(() => sanitizeSyncChanges({ changes: { rooms: many } }));
});

test('무작위 토큰과 PKCE', async () => {
  const a = randomToken(32);
  assert.match(a, /^[A-Za-z0-9_-]{43}$/);
  assert.notEqual(a, randomToken(32));
  // RFC 7636 부록 B 예시
  assert.equal(await pkceChallenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
    'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM');
});
