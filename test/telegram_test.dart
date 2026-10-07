import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_amatda/data/local_store.dart';
import 'package:flutter_application_amatda/models/task_item.dart';
import 'package:flutter_application_amatda/models/task_reminder.dart';
import 'package:flutter_application_amatda/models/telegram_room.dart';
import 'package:flutter_application_amatda/services/api_client.dart';
import 'package:flutter_application_amatda/services/telegram_link.dart';
import 'package:flutter_application_amatda/services/telegram_payload.dart';

const _api = 'https://bot.example.dev';

/// 봇 서버 흉내: 계정 하나의 텔레그램 연결 상태와 받은 일정을 기억한다
class _FakeBot {
  bool linked = false;
  String roomUrl = '';
  int codes = 0;
  final puts = <List<dynamic>>[];
  late final client = MockClient((req) async {
    expect(req.headers['Authorization'], 'Bearer tok');
    final path = req.url.path;
    http.Response ok(Object body) => http.Response(jsonEncode(body), 200,
        headers: {'content-type': 'application/json; charset=utf-8'});
    if (path == '/api/telegram/code') return ok({'code': 'code${++codes}'});
    if (path == '/api/telegram' && req.method == 'GET') {
      return ok({'linked': linked, 'name': linked ? '민준' : null, 'roomUrl': roomUrl});
    }
    if (path == '/api/telegram/room' && req.method == 'PUT') {
      roomUrl = (jsonDecode(req.body) as Map)['url'] as String;
      return ok({'roomUrl': roomUrl});
    }
    if (path == '/api/telegram' && req.method == 'DELETE') {
      linked = false;
      return ok({'linked': false});
    }
    if (path == '/api/reminders' && req.method == 'PUT') {
      if (!linked) return http.Response('{"linked":false}', 404);
      puts.add((jsonDecode(req.body) as Map)['reminders'] as List);
      return ok({'ok': true});
    }
    return http.Response('not found', 404);
  });

  ApiClient get api => ApiClient(baseUrl: _api, token: () => 'tok', client: client);
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('봇에 올릴 알림 일정', () {
    final now = DateTime(2026, 10, 6, 12);
    TaskItem task(String id, DateTime due, List<TaskReminder> r, {bool done = false}) =>
        TaskItem(id: id, title: id, dueDate: due, reminders: r,
                createdAt: DateTime(2026, 10, 1))
            .markDone(done);

    test('앞으로 울릴 알림은 모두, 지난 알림은 가장 최근 하나만', () {
      final items = buildTelegramReminders(now: now, rooms: const [], tasks: [
        task('a', DateTime(2026, 10, 6, 13), const [
          TaskReminder(amount: 1, unit: ReminderUnit.day), // 지남
          TaskReminder(amount: 2, unit: ReminderUnit.hour), // 지남(더 최근)
          TaskReminder(amount: 30, unit: ReminderUnit.minute), // 앞으로
        ]),
      ]);
      expect(items, hasLength(2));
      expect(items.first['text'], contains('(2시간 전)'));
      expect(items.last['text'], contains('(30분 전)'));
      expect(items.last['text'], contains('10월 6일 (화) 13:00'));
    });

    test('완료한 할 일, 마감이 한참 지난 것, 알림 없는 것은 빼고 업무방 마감은 포함', () {
      const r = [TaskReminder(amount: 1, unit: ReminderUnit.hour)];
      final room = TelegramRoom(
        id: 'r', name: '기획', type: TelegramRoomType.group, inviteLink: '',
        lastActivityAt: now, dueDate: DateTime(2026, 10, 7), reminders: r,
      );
      final items = buildTelegramReminders(now: now, rooms: [room], tasks: [
        task('done', DateTime(2026, 10, 7), r, done: true),
        task('stale', DateTime(2026, 10, 5), r),
        task('none', DateTime(2026, 10, 7), const []),
      ]);
      expect(items.single['key'], startsWith('room:r:'));
      expect(items.single['text'], startsWith('[업무방 마감] 기획\n[마감기한] '));
    });
  });

  group('텔레그램 연결', () {
    test('코드 준비 → 연결 → 확인 → 일정 업로드(변경 없으면 생략) → 끊기', () async {
      final bot = _FakeBot();
      final store = (await LocalStore.open()).forUser('u_1');
      final link = TelegramLink(api: bot.api, store: store, botUsername: 'amatda_bot');

      expect(link.available, isTrue);
      expect(link.startUrl(), isNull, reason: '코드를 아직 받지 않았으면 준비만 한다');
      await link.prepare();
      final url = link.startUrl()!;
      expect(url.host, 't.me');
      expect(url.queryParameters['start'], 'code1');
      expect(link.pending, isTrue);

      expect(await link.refresh(), isFalse); // 아직 '시작'을 누르지 않음
      bot.linked = true;
      expect(await link.refresh(), isTrue);
      expect(link.linked, isTrue);
      expect(link.chatName, '민준');

      final payload = [
        {'key': 'k', 'fireAt': 1, 'dueAt': 2, 'text': 't'},
      ];
      await link.sync(payload);
      await link.sync(payload);
      expect(bot.puts, hasLength(1), reason: '같은 일정은 다시 보내지 않는다');

      // 다시 열어도 연결 상태가 유지된다 (같은 계정)
      expect(TelegramLink(api: bot.api, store: store).linked, isTrue);
      expect(TelegramLink(api: bot.api, store: store.forUser('u_2')).linked, isFalse);

      await link.disconnect();
      expect(link.linked, isFalse);
      expect(link.pending, isFalse);
      expect(bot.linked, isFalse);
    });

    test('업무방 링크는 계정에 저장되고, 다른 기기에서 바꾼 값도 받아온다', () async {
      final bot = _FakeBot()..linked = true;
      final store = (await LocalStore.open()).forUser('u_1');
      final link = TelegramLink(api: bot.api, store: store, botUsername: 'b');
      await link.refresh();
      expect(link.roomUrl, '');

      expect(await link.saveRoomUrl('https://t.me/+team'), isNull);
      expect(bot.roomUrl, 'https://t.me/+team');
      expect(TelegramLink(api: bot.api, store: store).roomUrl, 'https://t.me/+team',
          reason: '다시 열어도 서버 응답 전에 바로 쓸 수 있다');

      bot.roomUrl = 'https://t.me/+other'; // 다른 기기에서 바꿈
      expect(await link.refresh(), isTrue);
      expect(link.roomUrl, 'https://t.me/+other');
    });

    test('텔레그램에서 /stop 하면 다음 업로드 때 연결 해제로 바뀐다', () async {
      final bot = _FakeBot()..linked = true;
      final link = TelegramLink(api: bot.api, botUsername: 'b');
      await link.refresh();
      expect(link.linked, isTrue);
      bot.linked = false;
      await link.sync(const []);
      expect(link.linked, isFalse);
    });

    test('로그인하지 않았으면(서버 연결 없음) 기능을 쓸 수 없다', () {
      expect(TelegramLink(botUsername: 'b').available, isFalse);
    });
  });
}
