import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_amatda/data/model_json.dart';
import 'package:flutter_application_amatda/data/sync_records.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/models/routine.dart';
import 'package:flutter_application_amatda/providers/routine_provider.dart';
import 'package:flutter_application_amatda/services/launch_link.dart';
import 'package:flutter_application_amatda/widgets/composer_frame.dart';
import 'package:flutter_application_amatda/widgets/routine_tile.dart';
import 'package:provider/provider.dart';

Routine _routine(String id, {String? roomId}) => Routine(
      id: id,
      name: '루틴 $id',
      weekdays: everyDay,
      roomId: roomId,
      createdAt: DateTime(2026, 10, 1),
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

RoutineProvider _routines(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first).read<RoutineProvider>();

/// [앱에서 보기]로 task_001이 있는 '팀 프로젝트 - 아맞다'(room_001) 업무방을 연다
Future<void> _openRoom001(WidgetTester tester) async {
  debugSetLaunchTarget((kind: 'task', id: 'task_001'));
  await _boot(tester);
}

void main() {
  test('루틴의 업무방은 저장·동기화 후에도 유지되고, 예전 루틴은 미지정이다', () {
    final records = toRecords(const [], const [], [_routine('a', roomId: 'room_1')]);
    expect(records['routines']!['a']!.parentId, 'room_1');
    expect(fromRecords(records).routines.single.roomId, 'room_1');

    final legacy = routineToJson(_routine('b'))..remove('roomId');
    expect(routineFromJson(legacy).roomId, isNull);
  });

  test('업무방 연결 해제는 그 방의 루틴만 바꾼다', () {
    final p = RoutineProvider()
      ..replaceAll([_routine('a', roomId: 'r1'), _routine('b', roomId: 'r2')]);
    p.unlinkRoom('r1');
    expect([for (final r in p.routines) r.roomId], [null, 'r2']);
    expect(p.routinesForRoom('r2').single.id, 'b');
  });

  testWidgets('업무방 [루틴] 탭: 이 방 루틴만 보이고 오늘 체크한다', (tester) async {
    await _openRoom001(tester);
    _routines(tester).replaceAll(
        [_routine('mine', roomId: 'room_001'), _routine('other', roomId: 'room_002')]);
    await tester.pumpAndSettle();

    await _tap(tester, find.text('루틴 1'));
    expect(find.text('루틴 mine'), findsOneWidget);
    expect(find.text('루틴 other'), findsNothing);
    expect(
        find.descendant(
            of: find.byType(RoutineTile), matching: find.text('팀 프로젝트 - 아맞다')),
        findsNothing,
        reason: '업무방 화면 안에서는 방 이름 칩을 반복하지 않는다');

    await _tap(tester, find.text('루틴 mine'));
    expect(_routines(tester).routineById('mine')!.isDoneOn(DateTime.now()), isTrue);
  });

  testWidgets('업무방에서 루틴을 추가하면 그 방이 미리 선택된다', (tester) async {
    await _openRoom001(tester);
    await _tap(tester, find.text('추가'));
    await _tap(tester, find.text('루틴 추가'));
    await tester.enterText(
        find.descendant(
            of: find.byType(ComposerFrame), matching: find.byType(TextField)),
        '주간 회의 준비');
    await tester.pump();
    await _tap(tester, find.text('추가하기'));

    final added =
        _routines(tester).routines.firstWhere((r) => r.name == '주간 회의 준비');
    expect(added.roomId, 'room_001');
    expect(find.text('주간 회의 준비'), findsOneWidget, reason: '루틴 탭으로 바뀌어 보인다');
  });

  testWidgets('루틴 탭 목록에 업무방 이름 칩이 보인다', (tester) async {
    await _boot(tester);
    _routines(tester).replaceAll([_routine('linked', roomId: 'room_001')]);
    await _tap(tester, find.text('오늘 할일'));
    await _tap(tester, find.text('루틴').last);

    final tile = find.byType(RoutineTile);
    expect(find.descendant(of: tile, matching: find.text('팀 프로젝트 - 아맞다')),
        findsOneWidget);
  });

  testWidgets('업무방을 삭제하면 루틴은 남고 연결만 풀린다', (tester) async {
    await _openRoom001(tester);
    _routines(tester).replaceAll([_routine('mine', roomId: 'room_001')]);
    await tester.pumpAndSettle();

    await _tap(tester, find.byTooltip('방 삭제'));
    expect(find.textContaining('연결된 루틴은 남고'), findsOneWidget);
    await _tap(tester, find.text('삭제'));

    final routine = _routines(tester).routineById('mine')!;
    expect(routine.roomId, isNull);
  });
}
