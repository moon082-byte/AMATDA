import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_amatda/data/sync_records.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/models/sub_task.dart';
import 'package:flutter_application_amatda/models/task_item.dart';
import 'package:flutter_application_amatda/providers/room_provider.dart';
import 'package:flutter_application_amatda/services/launch_link.dart';
import 'package:flutter_application_amatda/services/reminder_checker.dart';
import 'package:flutter_application_amatda/services/telegram_payload.dart';
import 'package:flutter_application_amatda/utils/date_format.dart';
import 'package:flutter_application_amatda/widgets/composer_frame.dart';
import 'package:provider/provider.dart';

final _at = DateTime(2026, 10, 6, 17, 30);

TaskItem _task({DateTime? due}) => TaskItem(
      id: 't1',
      title: '주간 보고서',
      dueDate: due,
      createdAt: DateTime(2026, 10, 1),
      subTasks: [
        SubTask(id: 's1', title: '자료 취합', remindAt: [_at]),
        SubTask(id: 's2', title: '끝난 항목', isDone: true, remindAt: [_at]),
      ],
    );

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

RoomProvider _rooms(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first).read<RoomProvider>();

void main() {
  final now = DateTime(2026, 10, 6, 12);
  final due = DateTime(2026, 10, 6, 18);

  test('텔레그램 알림에 할일명과 세부항목명이 함께 들어간다 (완료한 항목 제외)', () {
    final items = buildTelegramReminders(
        now: now, rooms: const [], tasks: [_task(due: due)]);
    expect(items, hasLength(1));
    expect(items.single['key'], startsWith('sub:t1:s1:'));
    expect(items.single['fireAt'], _at.millisecondsSinceEpoch);
    expect((items.single['text'] as String).split('\n'), [
      '[체크리스트 업무] 주간 보고서',
      '[세부항목] 자료 취합',
      '[알림시각] 10월 6일 (화) 17:30',
      '[마감기한] 10월 6일 (화) 18:00',
    ]);
  });

  test('할 일에 마감이 없어도 세부 항목 리마인더는 울린다', () {
    final items =
        buildTelegramReminders(now: now, rooms: const [], tasks: [_task()]);
    expect(items.single['text'], isNot(contains('[마감기한]')));
    final local = collectDueReminders(
        tasks: [_task()], now: _at.add(const Duration(minutes: 1)), fired: {});
    expect(local.single.body, '리마인더 시각이에요');
  });

  test('브라우저 알림: 시각이 되면 "할 일 · 세부 항목"으로 한 번 울린다', () {
    final at = _at.add(const Duration(minutes: 1));
    final first = collectDueReminders(tasks: [_task(due: due)], now: at, fired: {});
    expect(first.single.title, '주간 보고서 · 자료 취합');
    final again = collectDueReminders(
        tasks: [_task(due: due)], now: at, fired: {...first.single.alsoCovers});
    expect(again, isEmpty);
  });

  test('세부 항목 리마인더가 동기화 변환 후에도 유지된다', () {
    final back =
        fromRecords(toRecords(const [], [_task(due: due)], const [])).tasks.single;
    expect([for (final s in back.subTasks) s.remindAt], [
      [_at],
      [_at],
    ]);
  });

  testWidgets('세부 항목 🔔 → [📅 날짜][🕐 시간] 줄 추가 → 활성 표시', (tester) async {
    debugSetLaunchTarget((kind: 'task', id: 'task_001'));
    await _boot(tester);
    final task = _rooms(tester).taskById('task_001')!;
    final expected = task.dueDate!.subtract(const Duration(hours: 1));

    await _tap(tester, find.byTooltip('리마인더 설정').at(1)); // 보고서 초안 작성
    expect(find.text('리마인더 · 보고서 초안 작성'), findsOneWidget);
    await _tap(tester, find.text('리마인더 추가')); // 기본: 마감 1시간 전
    expect(find.text('17:00'), findsOneWidget);
    expect(
      find.text('${expected.month}/${expected.day} (${koWeekdayShort(expected)})'),
      findsOneWidget,
    );

    // 🕐 시간 선택 팝업이 열리고, 확인하면 값이 그대로 유지된다
    await _tap(tester, find.byTooltip('리마인드 시간'));
    expect(find.text('리마인드 시간 선택'), findsOneWidget);
    await _tap(tester, find.text('확인').last);
    await _tap(tester, find.text('확인')); // 리마인더 팝업 확인

    final sub = _rooms(tester).taskById('task_001')!.subTasks[1];
    expect(sub.remindAt, [expected]);
    expect(find.byTooltip('리마인더 1개'), findsOneWidget);
  });

  testWidgets('추가 → 할 일: 마감 없이도 🔔으로 알림 시각을 건다', (tester) async {
    await _boot(tester);
    await _tap(tester, find.text('오늘 할일'));
    await _tap(tester, find.text('추가'));
    await _tap(tester, find.text('할 일 추가'));

    final block = find.byType(ComposerFrame);
    await tester.enterText(
        find.descendant(of: block, matching: find.byType(TextField)).first, '견적서 발송');
    await _tap(tester,
        find.descendant(of: block, matching: find.byTooltip('리마인더 설정')));
    await _tap(tester, find.text('리마인더 추가'));
    await _tap(tester, find.text('리마인더 추가'));
    expect(find.byTooltip('리마인드 날짜'), findsNWidgets(2));
    await _tap(tester, find.text('확인'));
    expect(find.byTooltip('리마인더 2개'), findsOneWidget);
    await _tap(tester, find.text('추가하기'));

    final added =
        _rooms(tester).tasks.firstWhere((t) => t.title == '견적서 발송');
    expect(added.dueDate, isNull);
    expect(added.remindAt, hasLength(2));
    expect(added.remindAt.last.difference(added.remindAt.first),
        const Duration(hours: 1));
  });
}
