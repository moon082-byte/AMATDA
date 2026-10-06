import assert from 'node:assert/strict';
import { test } from 'node:test';
import { hmacHex, randomDigits, safeEqual } from '../src/crypto.js';
import { PIN_PATTERN, nextPinState, pinLockDuration } from '../src/logic.js';

test('5번 틀리면 처음엔 1분, 그 뒤로는 30분 잠근다', () => {
  let s = { failed: 0, lockedUntil: 0, level: 0 };
  for (let i = 1; i <= 4; i++) {
    s = nextPinState(s, false, 1000);
    assert.equal(s.failed, i);
    assert.equal(s.lockedUntil, 0);
  }
  s = nextPinState(s, false, 1000);
  assert.deepEqual(s, { failed: 0, lockedUntil: 1000 + 60 * 1000, level: 1 });

  for (let i = 0; i < 5; i++) s = nextPinState(s, false, 2000);
  assert.deepEqual(s, { failed: 0, lockedUntil: 2000 + 30 * 60 * 1000, level: 2 });
  assert.equal(pinLockDuration(5), 30 * 60 * 1000);
});

test('맞게 입력하면 횟수와 잠금 단계가 처음으로 돌아간다', () => {
  const s = nextPinState({ failed: 3, lockedUntil: 0, level: 2 }, true, 0);
  assert.deepEqual(s, { failed: 0, lockedUntil: 0, level: 0 });
});

test('PIN 형식, 해시, 비교', async () => {
  assert.ok(PIN_PATTERN.test('0123'));
  for (const bad of ['123', '12345', 'abcd', '12 4', '']) assert.ok(!PIN_PATTERN.test(bad));

  const a = await hmacHex('pepper', 'salt:1234');
  assert.match(a, /^[0-9a-f]{64}$/);
  assert.equal(a, await hmacHex('pepper', 'salt:1234'));
  assert.notEqual(a, await hmacHex('other', 'salt:1234'), '서버 비밀키가 다르면 해시도 다르다');
  assert.ok(safeEqual(a, a));
  assert.ok(!safeEqual(a, a.replace(/.$/, 'x')));
  assert.ok(!safeEqual(a, undefined));

  assert.match(randomDigits(6), /^\d{6}$/);
});
