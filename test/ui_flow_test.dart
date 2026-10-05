import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/models/task_item.dart';
import 'package:flutter_application_amatda/models/task_reminder.dart';
import 'package:flutter_application_amatda/providers/room_provider.dart';
import 'package:flutter_application_amatda/widgets/reminder_banner.dart';
import 'package:provider/provider.dart';

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
}

RoomProvider _provider(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first).read<RoomProvider>();

List<String> _activeTitles(WidgetTester tester) =>
    [for (final TaskItem t in _provider(tester).activeTasks) t.title];

void main() {
  testWidgets('할 일을 체크한 뒤 실행 취소하면 원래 자리로 돌아온다', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('오늘 할일'));
    await tester.pumpAndSettle();
    final before = _activeTitles(tester);

    await tester.tap(find.text(before.first));
    await tester.pump(); // 알림 애니메이션 시작
    await tester.pump(const Duration(milliseconds: 600)); // 다 올라올 때까지
    expect(find.text('실행 취소'), findsOneWidget);
    expect(_activeTitles(tester), isNot(contains(before.first)));

    await tester.tap(find.text('실행 취소'));
    await tester.pumpAndSettle();
    expect(_activeTitles(tester), before);
  });

  testWidgets('할 일을 꾹 눌러 끌면 순서가 바뀐다', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('오늘 할일'));
    await tester.pumpAndSettle();
    final before = _activeTitles(tester);
    expect(before.length, greaterThan(1));

    final gesture =
        await tester.startGesture(tester.getCenter(find.text(before.first)));
    await tester.pump(const Duration(milliseconds: 700)); // 꾹 누르기
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, 20));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(_activeTitles(tester), [before[1], before[0], ...before.skip(2)]);
  });

  testWidgets('외부링크가 여러 개면 팝업 목록에서 고른다', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('오늘 할일'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('팀 프로젝트 - 아맞다').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('외부링크 열기 · 2개'));
    await tester.pumpAndSettle();
    expect(find.text('외부 링크 열기'), findsOneWidget);
    expect(find.text('노션'), findsOneWidget);
    expect(find.text('카카오톡'), findsOneWidget);
  });

  testWidgets('업무방 수정 화면에서 업무 링크를 추가할 수 있다', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('오늘 할일'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('김철수').first);
    await tester.pumpAndSettle();
    expect(find.textContaining('외부링크 열기'), findsNothing);

    await tester.tap(find.byTooltip('업무방 수정'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('링크 추가'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'notion.so/kim');
    await tester.tap(find.text('저장').first);
    await tester.pumpAndSettle();

    expect(find.text('외부링크 열기 · 노션'), findsOneWidget);
    final room = _provider(tester).rooms.firstWhere((r) => r.name == '김철수');
    expect(room.workLinks, ['https://notion.so/kim']);
  });

  testWidgets('리마인드 시각이 되면 화면 위에 알림 배너가 뜬다', (tester) async {
    await _boot(tester);
    _provider(tester).addTask(TaskItem(
      id: 'soon',
      title: '거래처 미팅 자료 보내기',
      dueDate: DateTime.now().add(const Duration(minutes: 20)),
      reminder: const TaskReminder(amount: 30, unit: ReminderUnit.minute),
      createdAt: DateTime.now(),
    ));
    await tester.pump(const Duration(seconds: 21)); // 20초마다 확인
    await tester.pump(const Duration(milliseconds: 400));

    // 같은 제목이 메인 화면의 '오늘 마감 일정'에도 보일 수 있으므로(실행 시각에 따라)
    // 배너 안에서만 찾는다
    Finder inBanner(Finder f) =>
        find.descendant(of: find.byType(ReminderBanner), matching: f);

    expect(tester.takeException(), isNull);
    expect(inBanner(find.text('거래처 미팅 자료 보내기')), findsOneWidget);
    expect(inBanner(find.textContaining('남았어요')), findsOneWidget);

    await tester.tap(inBanner(find.bySemanticsLabel('닫기')));
    await tester.pumpAndSettle();
    expect(find.byType(ReminderBanner), findsNothing);
  });
}
