import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_amatda/data/model_json.dart';
import 'package:flutter_application_amatda/data/sync_records.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/models/project_link.dart';
import 'package:flutter_application_amatda/models/task_item.dart';
import 'package:flutter_application_amatda/providers/room_provider.dart';
import 'package:flutter_application_amatda/widgets/composer_frame.dart';
import 'package:flutter_application_amatda/widgets/round_check.dart';
import 'package:flutter_application_amatda/widgets/task_detail_card.dart';
import 'package:provider/provider.dart';

const _link = ProjectLink(roomId: 'r1', roomName: '신제품', projectName: '디자인', taskId: 't1');

TaskItem _assigned({bool done = false}) => TaskItem(
      id: 'pt_t1',
      title: '시안 만들기',
      dueDate: DateTime.now().add(const Duration(days: 2)),
      createdAt: DateTime.now(),
      project: _link,
    ).markDone(done);

Future<RoomProvider> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
  final rooms = tester.element(find.byType(Scaffold).first).read<RoomProvider>();
  rooms.addTask(_assigned());
  await tester.ensureVisible(find.text('오늘 할일').first);
  await tester.tap(find.text('오늘 할일').first);
  await tester.pumpAndSettle();
  // 새 할 일은 목록 맨 아래에 있으므로 보이게 내린다
  await tester.scrollUntilVisible(find.text('시안 만들기'), 300,
      scrollable: find.descendant(of: find.byType(CustomScrollView).last, matching: find.byType(Scrollable)).first);
  await tester.pumpAndSettle();
  return rooms;
}

Finder _card() => find.ancestor(of: find.text('시안 만들기'), matching: find.byType(TaskDetailCard));

void main() {
  test('서버가 넣은 프로젝트 업무(UTC 마감·연결 정보)를 읽고 동기화 변환 후에도 유지한다', () {
    final t = taskFromJson({
      'id': 'pt_t1', 'title': '시안', 'createdAt': '2026-10-20T00:00:00.000Z',
      'dueDate': '2026-11-20T09:00:00.000Z', 'project': _link.toJson(),
    });
    expect(t.dueDate!.isUtc, isFalse, reason: '이 기기 시간대로 바꿔 읽는다');
    expect(t.dueDate!.toUtc(), DateTime.utc(2026, 11, 20, 9));
    final back = fromRecords(toRecords(const [], [t], const [])).tasks.single;
    expect([back.project?.label, back.project?.taskId], ['신제품방 · 디자인', 't1']);
  });

  testWidgets('개인 할일에서 체크하면 "신제품방 - 업무 완료입니까?"를 묻고, 확인하면 완료된다', (tester) async {
    final rooms = await _boot(tester);
    expect(find.descendant(of: _card(), matching: find.text('신제품방 · 디자인')), findsOneWidget);
    expect(find.descendant(of: _card(), matching: find.byIcon(Icons.lock_rounded)), findsOneWidget);

    await tester.tap(find.descendant(of: _card(), matching: find.byType(RoundCheckButton)));
    await tester.pumpAndSettle();
    expect(find.text('신제품방 - 시안 만들기 업무 완료입니까?'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(rooms.taskById('pt_t1')!.isDone, isFalse);

    await tester.tap(find.descendant(of: _card(), matching: find.byType(RoundCheckButton)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('확인'));
    await tester.pumpAndSettle();
    expect(rooms.taskById('pt_t1')!.isDone, isTrue);
    expect(find.text('실행 취소'), findsNothing, reason: '완료 보고는 되돌리지 않는다');
  });

  testWidgets('수정 화면: 이름·마감은 잠기고 업무방 태그만 바뀌며, 삭제 버튼이 없다', (tester) async {
    final rooms = await _boot(tester);
    final due = rooms.taskById('pt_t1')!.dueDate;
    await tester.drag(_card(), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('삭제'), findsNothing);
    await tester.tap(find.text('수정'));
    await tester.pumpAndSettle();

    final field = tester.widget<TextField>(
        find.descendant(of: find.byType(ComposerFrame), matching: find.byType(TextField)).first);
    expect(field.readOnly, isTrue);
    expect(find.byTooltip('마감은 팀장만 바꿀 수 있어요'), findsOneWidget);

    final roomName = rooms.rooms.first.name;
    await tester.ensureVisible(find.widgetWithText(ChoiceChip, roomName));
    await tester.tap(find.widgetWithText(ChoiceChip, roomName));
    await tester.pump();
    await tester.tap(find.text('저장하기'));
    await tester.pumpAndSettle();
    final saved = rooms.taskById('pt_t1')!;
    expect([saved.roomId, saved.title, saved.dueDate], [rooms.rooms.first.id, '시안 만들기', due]);
  });
}
