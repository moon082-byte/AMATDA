import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/providers/room_provider.dart';
import 'package:flutter_application_amatda/providers/routine_provider.dart';
import 'package:flutter_application_amatda/services/launch_link.dart';
import 'package:flutter_application_amatda/utils/date_format.dart';
import 'package:provider/provider.dart';

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
}

T _read<T>(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first).read<T>();

/// [앱에서 보기]로 '주간 보고서' 할 일(task_001)을 펼친 채 연다
Future<void> _openTask001(WidgetTester tester) async {
  debugSetLaunchTarget((kind: 'task', id: 'task_001'));
  await _boot(tester);
  expect(find.text('세부 체크리스트'), findsOneWidget);
}

void main() {
  testWidgets('완료 후 실행 취소 알림은 5초 뒤 저절로 사라진다', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('오늘 할일'));
    await tester.pumpAndSettle();
    final first = _read<RoomProvider>(tester).activeTasks.first.title;

    await tester.tap(find.text(first));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('실행 취소'), findsOneWidget);

    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('실행 취소'), findsNothing);
  });

  testWidgets('추가 버튼 → 루틴 추가로 새 루틴을 만든다', (tester) async {
    await _boot(tester);
    await tester.tap(find.text('오늘 할일'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('추가'));
    await tester.pumpAndSettle();
    expect(find.text('할 일 추가'), findsOneWidget);
    await tester.tap(find.text('루틴 추가'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '스트레칭');
    await tester.tap(find.text('평일'));
    await tester.pump();
    await tester.tap(find.text('저장').first);
    await tester.pumpAndSettle();

    final added = _read<RoutineProvider>(tester)
        .routines
        .firstWhere((r) => r.name == '스트레칭');
    expect(added.repeatLabel, '평일');
    expect(added.reminders.single.label, '정시');
    expect(find.text('스트레칭'), findsOneWidget); // 루틴 탭에 보인다
  });

  testWidgets('메인의 오늘의 루틴에서 체크하고, 전체 보기로 루틴 탭을 연다', (tester) async {
    await _boot(tester);
    expect(find.text('오늘의 일정'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('물 한 잔 마시기'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
    await tester.pumpAndSettle();
    await tester.tap(find.text('물 한 잔 마시기'));
    await tester.pump();
    final today = dateOnly(DateTime.now());
    expect(
      _read<RoutineProvider>(tester).routineById('routine_002')!.isDoneOn(today),
      isTrue,
    );

    await tester.tap(find.text('전체 보기 ›'));
    await tester.pumpAndSettle();
    expect(find.text('오늘의 루틴'), findsOneWidget);
    expect(find.textContaining('오늘 루틴'), findsOneWidget); // 부제목
  });

  testWidgets('세부 항목: 글자를 눌러 고치고, X로 지운 뒤 되돌린다', (tester) async {
    await _openTask001(tester);
    RoomProvider p() => _read<RoomProvider>(tester);
    List<String> titles() =>
        [for (final s in p().taskById('task_001')!.subTasks) s.title];

    await tester.tap(find.text('보고서 초안 작성'));
    await tester.pump();
    await tester.enterText(
        find.widgetWithText(TextField, '보고서 초안 작성'), '보고서 초안 완성');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(titles(), contains('보고서 초안 완성'));

    final deleteButtons = find.byTooltip('세부 항목 삭제');
    await tester.tap(deleteButtons.last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(titles(), isNot(contains('팀장 검토 요청')));
    await tester.tap(find.text('실행 취소'));
    await tester.pumpAndSettle();
    expect(titles().last, '팀장 검토 요청');
  });

  testWidgets('업무 메모를 밀어서 수정한다', (tester) async {
    await _openTask001(tester);
    await tester.drag(find.text('금요일 오전까지 초안 공유하기'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.widgetWithText(TextField, '금요일 오전까지 초안 공유하기'), '목요일까지 공유');
    await tester.tap(find.text('저장'));
    await tester.pumpAndSettle();
    final notes = _read<RoomProvider>(tester).taskById('task_001')!.notes;
    expect(notes.single.content, '목요일까지 공유');
  });

  testWidgets('없는 항목 링크로 들어오면 안내만 띄운다', (tester) async {
    debugSetLaunchTarget((kind: 'routine', id: 'gone'));
    await _boot(tester);
    expect(find.textContaining('항목을 찾을 수 없어요'), findsOneWidget);
  });
}
