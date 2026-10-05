import assert from 'node:assert/strict';
import { test } from 'node:test';
import { CODE_PATTERN, parseCommand, sanitizeReminders } from '../src/logic.js';

test('명령어 해석', () => {
  assert.deepEqual(parseCommand('/start abcdefghijklmnop'), { command: 'start', arg: 'abcdefghijklmnop' });
  assert.deepEqual(parseCommand('/START@amatda_bot xyz'), { command: 'start', arg: 'xyz' });
  assert.deepEqual(parseCommand('/stop'), { command: 'stop', arg: '' });
  assert.equal(parseCommand('안녕'), null);
  assert.equal(parseCommand(undefined), null);
});

test('연결 코드 형식', () => {
  assert.ok(CODE_PATTERN.test('a1B2_c3-D4e5F6g7h8'));
  assert.ok(!CODE_PATTERN.test('짧음'));
  assert.ok(!CODE_PATTERN.test('has space in code!!'));
  assert.ok(!CODE_PATTERN.test('x'.repeat(65)));
});

test('알림 목록 검사: 잘못된 항목과 중복은 버린다', () => {
  const items = sanitizeReminders({
    reminders: [
      { key: 'a', fireAt: 1, dueAt: 2, text: '할 일' },
      { key: 'a', fireAt: 1, dueAt: 2, text: '중복' },
      { key: 'b', fireAt: 'x', dueAt: 2, text: '시각 오류' },
      { key: '', fireAt: 1, dueAt: 2, text: '키 없음' },
      { key: 'c', fireAt: 3, dueAt: 4, text: 'x'.repeat(5000) },
    ],
  });
  assert.deepEqual(items.map((i) => i.key), ['a', 'c']);
  assert.equal(items[1].text.length, 1000);
});

test('알림 목록 검사: 형식이 틀리거나 너무 많으면 거부', () => {
  assert.throws(() => sanitizeReminders({}));
  const many = Array.from({ length: 301 }, (_, i) => ({ key: `${i}`, fireAt: 1, dueAt: 1, text: 't' }));
  assert.throws(() => sanitizeReminders({ reminders: many }));
});
