import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/models/sub_task.dart';
import 'package:flutter_application_amatda/models/task_item.dart';
import 'package:flutter_application_amatda/providers/room_provider.dart';
import 'package:flutter_application_amatda/services/launch_link.dart';
import 'package:flutter_application_amatda/utils/task_progress.dart';
import 'package:provider/provider.dart';

RoomProvider _rooms(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first).read<RoomProvider>();

/// 샘플 할 일 '주간 보고서 작성'(세부 항목 3개 중 1개 완료)을 펼친 채로 연다
Future<void> _openTask001(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  debugSetLaunchTarget((kind: 'task', id: 'task_001'));
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
}

void main() {
  test('진행률: 세부 항목 완료 비율, 없으면 완료 여부로 0 또는 1', () {
    final now = DateTime(2026, 10, 13);
    final empty = TaskItem(id: 'a', title: 'a', createdAt: now);
    expect(taskProgress(empty), 0);
    expect(taskProgress(empty.markDone(true)), 1);
    final withSubs = empty.copyWith(subTasks: const [
      SubTask(id: 's1', title: '1', isDone: true),
      SubTask(id: 's2', title: '2'),
      SubTask(id: 's3', title: '3'),
    ]);
    expect(taskProgress(withSubs), closeTo(1 / 3, 1e-9));
    expect(taskProgress(withSubs.markDone(true)), 1);
  });

  testWidgets('할 일 카드에 진행률(%)이 보이고, 세부 항목을 체크하면 바뀐다. 업무방 진행률은 없다', (tester) async {
    await _openTask001(tester);
    expect(find.text('진행률'), findsNothing);
    expect(find.text('33%'), findsOneWidget);
    await tester.tap(find.bySemanticsLabel('체크').first);
    await tester.pumpAndSettle();
    expect(find.text('67%'), findsOneWidget);
  });

  testWidgets('세부 항목을 꾹 눌러 끌면 순서가 바뀌고 저장된다', (tester) async {
    await _openTask001(tester);
    List<String> titles() => [for (final s in _rooms(tester).taskById('task_001')!.subTasks) s.title];
    final before = titles();
    final first = tester.getCenter(find.text(before.first));
    final third = tester.getCenter(find.text(before.last));

    final gesture = await tester.startGesture(first);
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    for (var i = 0; i < 4; i++) {
      await gesture.moveBy(Offset(0, (third.dy - first.dy + 60) / 4));
      await tester.pump(const Duration(milliseconds: 50));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(titles(), [before[1], before[2], before[0]]);
  });
}
