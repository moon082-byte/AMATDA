import assert from 'node:assert/strict';
import { test } from 'node:test';
import { CODE_PATTERN, parseCommand, sanitizeButtons, sanitizeReminders, sanitizeRoomUrl } from '../src/logic.js';
import { nagKeyboard } from '../src/nag.js';

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

test('링크 버튼 검사: http(s) 주소만, 최대 6개', () => {
  const buttons = sanitizeButtons([
    { text: '💬 텔레그램 업무방', url: 'https://t.me/+abcDEF123' },
    { text: '노션', url: 'javascript:alert(1)' },
    { text: '', url: 'https://a.com' },
    { text: '공백 주소', url: 'https://a.com/b c' },
    ...Array.from({ length: 8 }, (_, i) => ({ text: `링크${i}`, url: `http://x${i}.com` })),
  ]);
  assert.equal(buttons.length, 6);
  assert.equal(buttons[0].text, '💬 텔레그램 업무방');
  assert.deepEqual(sanitizeButtons('없음'), []);
});

test('알림에 버튼이 함께 저장되고 키보드로 바뀐다', () => {
  const [item] = sanitizeReminders({
    reminders: [{ key: 'a', fireAt: 1, dueAt: 2, text: 't', buttons: [{ text: '앱', url: 'https://a.com' }] }],
  });
  assert.deepEqual(item.buttons, [{ text: '앱', url: 'https://a.com' }]);
  assert.deepEqual(nagKeyboard(JSON.stringify(item.buttons), null), {
    inline_keyboard: [[{ text: '앱', url: 'https://a.com' }]],
  });
  assert.equal(nagKeyboard(null, null), undefined);
  assert.equal(nagKeyboard('깨진 값', null), undefined);
});

test('텔레그램 업무방 링크 검사: http(s)만, 비우면 빈 값', () => {
  assert.equal(sanitizeRoomUrl(' https://t.me/+abcDEF123 '), 'https://t.me/+abcDEF123');
  assert.equal(sanitizeRoomUrl(''), '');
  assert.equal(sanitizeRoomUrl(undefined), '');
  assert.throws(() => sanitizeRoomUrl('javascript:alert(1)'));
  assert.throws(() => sanitizeRoomUrl('https://t.me/a b'));
  assert.throws(() => sanitizeRoomUrl(`https://t.me/${'a'.repeat(500)}`));
});
