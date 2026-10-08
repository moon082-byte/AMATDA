import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_amatda/data/local_store.dart';
import 'package:flutter_application_amatda/models/routine.dart';
import 'package:flutter_application_amatda/models/task_item.dart';
import 'package:flutter_application_amatda/models/task_reminder.dart';
import 'package:flutter_application_amatda/models/telegram_room.dart';
import 'package:flutter_application_amatda/services/launch_link.dart';
import 'package:flutter_application_amatda/services/reminder_checker.dart';
import 'package:flutter_application_amatda/services/telegram_payload.dart';

const _onTime = TaskReminder(amount: 0, unit: ReminderUnit.minute);
const _tenMin = TaskReminder(amount: 10, unit: ReminderUnit.minute);

// 2026-10-06은 화요일
final _now = DateTime(2026, 10, 6, 8, 55);

Routine _routine({
  Set<int> days = everyDay,
  int hour = 9,
  List<TaskReminder> reminders = const [_onTime],
  Set<String> done = const {},
}) =>
    Routine(
      id: 'r1',
      name: '메일 확인',
      weekdays: days,
      hour: hour,
      reminders: reminders,
      doneDates: done,
      createdAt: DateTime(2026, 9, 1),
    );

void main() {
  test('반복 요일 요약과 다음 루틴 시각', () {
    expect(repeatLabelOf(everyDay), '매일');
    expect(repeatLabelOf(weekDays), '평일');
    expect(repeatLabelOf(weekendDays), '주말');
    expect(repeatLabelOf({5, 1, 3}), '월·수·금');
    expect(_onTime.label, '정시');

    final weekend = _routine(days: weekendDays);
    expect(weekend.occursOn(_now), isFalse);
    expect(weekend.nextOccurrence(_now), DateTime(2026, 10, 10, 9));
    expect(_routine().nextOccurrence(_now), DateTime(2026, 10, 6, 9));
    expect(_routine(days: {}).nextOccurrence(_now), isNull);
  });

  test('날짜별 완료 체크를 켜고 끌 수 있다', () {
    final r = _routine().toggledOn(_now);
    expect(r.isDoneOn(_now), isTrue);
    expect(r.isDoneOn(DateTime(2026, 10, 7)), isFalse);
    expect(r.toggledOn(_now).isDoneOn(_now), isFalse);
  });

  test('루틴이 저장 후에도 유지된다', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    await store.saveRoutines([
      _routine(days: {1, 3}, reminders: const [_tenMin], done: {'2026-10-05'}),
    ]);
    final loaded = (await LocalStore.open()).loadRoutines()!.single;
    expect(loaded.weekdays, {1, 3});
    expect(loaded.reminders, [_tenMin]);
    expect(loaded.isDoneOn(DateTime(2026, 10, 5)), isTrue);
  });

  test('루틴 리마인드는 시각이 되면 울리고, 오늘 완료했으면 울리지 않는다', () {
    List<DueReminder> due(Routine r, DateTime now) => collectDueReminders(
        tasks: const [], routines: [r], now: now, fired: {});

    final r = _routine(reminders: const [_tenMin]);
    expect(due(r, _now), hasLength(1));
    expect(due(r, _now).single.title, '메일 확인 루틴');
    expect(due(r, _now).single.body, '5분 뒤 루틴 시간이에요');
    expect(due(r, DateTime(2026, 10, 6, 8, 40)), isEmpty);
    expect(due(r.toggledOn(_now), _now), isEmpty);
  });

  test('만들기 전에 이미 지난 루틴 시각은 알리지 않는다', () {
    // 09:00 정시 알림 루틴을 10:00에 만든 상황
    final made = Routine(
      id: 'r2',
      name: '새 루틴',
      weekdays: everyDay,
      hour: 9,
      reminders: const [_onTime],
      createdAt: DateTime(2026, 10, 6, 10),
    );
    final now = DateTime(2026, 10, 6, 10, 1);
    expect(
        collectDueReminders(
            tasks: const [], routines: [made], now: now, fired: {}),
        isEmpty);
    final list = buildTelegramReminders(
        tasks: const [], rooms: const [], routines: [made], now: now);
    expect(list.first['fireAt'], DateTime(2026, 10, 7, 9).millisecondsSinceEpoch);

    // 고치면 고친 시각부터 다시 센다
    final edited = made.copyWithEdits(
        name: '새 루틴', weekdays: everyDay, hour: 8, minute: 0, reminders: const [_onTime]);
    expect(edited.remindFrom.isAfter(made.remindFrom), isTrue);
  });

  group('텔레그램 알림 일정', () {
    test('루틴은 앞으로 7일 치, 날짜마다 따로 올린다', () {
      final list = buildTelegramReminders(
          tasks: const [], rooms: const [], routines: [_routine()], now: _now);
      expect(list, hasLength(7)); // 6일 09:00 ~ 12일 09:00 (13일 09:00은 7일 넘게 남아 제외)
      expect(list.map((r) => r['key']).toSet(), hasLength(7));
      expect(list.first['text'] as String, startsWith('[루틴] '));
      expect(list.first['text'] as String, contains('(정시)'));
      final buttons = list.first['buttons'] as List;
      expect(buttons.single['text'], '📱 앱에서 보기');
      expect(buttons.single['url'], endsWith('?open=routine:r1'));
    });

    test('할 일 알림: 정해진 형식에 업무링크 줄, 버튼은 [앱에서 보기] 하나', () {
      final room = TelegramRoom(
        id: 'room1',
        name: '팀방',
        type: TelegramRoomType.group,
        inviteLink: '',
        memberCount: 3,
        lastActivityAt: _now,
        workLinks: const ['notion.so/team', 'https://example.com/a'],
      );
      final task = TaskItem(
        id: 't1',
        title: '보고서',
        roomId: 'room1',
        dueDate: _now.add(const Duration(hours: 2)),
        reminders: const [_tenMin],
        createdAt: _now,
      );
      final item = buildTelegramReminders(
          tasks: [task], rooms: [room], now: _now).single;
      expect((item['text'] as String).split('\n'), [
        '[체크리스트 업무] 보고서',
        '[마감기한] 10월 6일 (화) 10:55 (10분 전)',
        '[업무링크] https://notion.so/team',
        '[업무링크] https://example.com/a',
      ]);
      final buttons = item['buttons'] as List;
      expect(buttons.single['text'], '📱 앱에서 보기');
      expect(buttons.single['url'], endsWith('?open=task:t1'));

      // 링크가 없으면 그 줄은 빠진다
      final plain = buildTelegramReminders(
          tasks: [task], rooms: const [], now: _now).single;
      expect((plain['text'] as String).split('\n'), hasLength(2));
      expect(plain['text'] as String, isNot(contains('http')), reason: '업무링크가 없으면 그 줄은 빠진다');
      expect(plain['buttons'], hasLength(1));
    });

    test('너무 많으면 가까운 알림부터 300개만 올린다', () {
      final many = [
        for (var i = 0; i < 60; i++)
          Routine(
            id: 'r$i',
            name: '루틴 $i',
            weekdays: everyDay,
            hour: 10,
            reminders: const [_onTime],
            createdAt: _now,
          ),
      ];
      final list = buildTelegramReminders(
          tasks: const [], rooms: const [], routines: many, now: _now);
      expect(list, hasLength(kMaxTelegramReminders));
      final times = [for (final r in list) r['fireAt'] as int];
      expect(times, [...times]..sort());
    });
  });

  test('[앱에서 보기] 주소를 읽는다', () {
    final link = Uri.parse(appLinkFor('routine', 'routine_1'));
    expect(parseLaunchTarget(link), (kind: 'routine', id: 'routine_1'));
    expect(parseLaunchTarget(Uri.parse('https://a.com/?open=evil:1')), isNull);
    expect(parseLaunchTarget(Uri.parse('https://a.com/?open=task:')), isNull);
    expect(parseLaunchTarget(Uri.parse('https://a.com/')), isNull);
  });
}
