import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_amatda/data/model_json.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/models/project.dart';
import 'package:flutter_application_amatda/models/project_link.dart';
import 'package:flutter_application_amatda/models/task_item.dart';
import 'package:flutter_application_amatda/providers/room_provider.dart';
import 'package:flutter_application_amatda/views/archive_view.dart';
import 'package:flutter_application_amatda/widgets/overdue_task_card.dart';
import 'package:flutter_application_amatda/widgets/task_progress_bar.dart';
import 'package:provider/provider.dart';

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
}

/// 기한 지남 카드 안의 [완료] 버튼 (다른 '완료' 글자와 헷갈리지 않게)
final _doneButton = find.descendant(of: find.byType(OverdueTaskCard), matching: find.text('완료'));

RoomProvider _provider(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first).read<RoomProvider>();

TaskItem _task(String id, DateTime? due) =>
    TaskItem(id: id, title: id, dueDate: due, createdAt: DateTime(2026, 10, 1));

void main() {
  group('기한 지남 판단', () {
    final now = DateTime(2026, 10, 6, 12);

    test('시간을 정한 마감은 그 시각, 날짜만 정한 마감은 그날이 끝날 때 지난다', () {
      expect(_task('a', DateTime(2026, 10, 6, 11)).isOverdueAt(now), isTrue);
      expect(_task('b', DateTime(2026, 10, 6, 13)).isOverdueAt(now), isFalse);
      expect(_task('c', DateTime(2026, 10, 6)).overdueAt, DateTime(2026, 10, 7));
      expect(_task('c', DateTime(2026, 10, 6)).isOverdueAt(now), isFalse);
      expect(_task('d', DateTime(2026, 10, 5)).isOverdueAt(now), isTrue);
      expect(_task('e', null).isOverdueAt(now), isFalse);
    });

    test('완료·미완료 처리·검토중인 프로젝트 업무는 기한 지남이 아니다', () {
      final past = _task('p', DateTime(2026, 10, 5, 9));
      expect(past.markDone(true).isOverdueAt(now), isFalse);
      expect(past.markMissed(true).isOverdueAt(now), isFalse);
      final project = TaskItem(
        id: 'pt_1', title: '시안', dueDate: DateTime(2026, 10, 5, 9), createdAt: now,
        project: const ProjectLink(roomId: 'r', roomName: '신제품', projectName: '디자인', taskId: '1'),
      );
      expect(project.isOverdueAt(now), isTrue);
      expect(project.withReview(true).isOverdueAt(now), isFalse);
    });

    test('미완료 처리 시각은 저장했다가 그대로 읽는다 (완료와 구분)', () {
      final missed = _task('m', DateTime(2026, 10, 5)).markMissed(true);
      final read = taskFromJson(Map<String, dynamic>.from(taskToJson(missed)));
      expect(read.isMissed, isTrue);
      expect(read.isDone, isFalse);
      expect(taskToJson(_task('n', null)).containsKey('missedAt'), isFalse);
    });

    test('프로젝트 세부업무: 미완료는 완료와 구분하고 진행 중 개수에서 빠진다', () {
      final t = ProjectTask.fromJson({'id': '1', 'title': '시안', 'missedAt': 1});
      expect(t.status, TaskStatus.missed);
      expect([t.isDone, t.isClosed], [false, true]);
      final done = ProjectTask.fromJson({'id': '2', 'title': '끝', 'doneAt': 2, 'missedAt': 1});
      expect(done.status, TaskStatus.done);
    });

    test('프로젝트 세부업무: 마감 뒤 최종완료는 기한 후 완료 (날짜만 정한 마감은 그날 끝까지)', () {
      int ms(DateTime d) => d.millisecondsSinceEpoch;
      ProjectTask t(DateTime due, DateTime done) =>
          ProjectTask.fromJson({'id': 'x', 'title': 't', 'dueAt': ms(due), 'doneAt': ms(done)});
      expect(t(DateTime(2026, 11, 3, 18), DateTime(2026, 11, 3, 19)).doneLate, isTrue);
      expect(t(DateTime(2026, 11, 3, 18), DateTime(2026, 11, 3, 17)).doneLate, isFalse);
      expect(t(DateTime(2026, 11, 3), DateTime(2026, 11, 3, 23)).doneLate, isFalse);
      expect(t(DateTime(2026, 11, 3), DateTime(2026, 11, 4, 1)).doneLate, isTrue);
      expect(ProjectTask.fromJson({'id': 'y', 'title': 't'}).doneLate, isFalse);
    });
  });

  testWidgets('기한 지난 할 일은 [기한 지남] 탭으로 옮겨지고, 미완료 처리하면 [완료된 일들]에 미완료로 남는다', (tester) async {
    await _boot(tester);
    final now = DateTime.now();
    final provider = _provider(tester);
    final completedBefore = provider.totalCompletedCount;
    provider.addTask(TaskItem(
      id: 'late', title: '어제 보고서', createdAt: now,
      dueDate: DateTime(now.year, now.month, now.day - 1, 10),
    ));
    await tester.tap(find.text('오늘 할일'));
    await tester.pumpAndSettle();
    expect(find.text('어제 보고서'), findsNothing, reason: '할일 목록에서는 빠진다');

    await tester.tap(find.text('기한 지남'));
    await tester.pumpAndSettle();
    expect(find.text('어제 보고서'), findsOneWidget);
    expect(find.text('기한 변경'), findsOneWidget);

    await tester.tap(find.text('미완료 처리'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '미완료 처리'));
    await tester.pumpAndSettle();
    expect(find.text('어제 보고서'), findsNothing);
    final missed = provider.taskById('late')!;
    expect([missed.isMissed, missed.isDone], [true, false]);
    expect(provider.archivedTasks.first.id, 'late');
    expect(provider.totalCompletedCount, completedBefore, reason: '완료 개수에는 넣지 않는다');

    Navigator.of(tester.element(find.byType(Scaffold).first))
        .push(MaterialPageRoute<void>(builder: (_) => const ArchiveView()));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^\d+:\d+ 미완료 처리$')), findsOneWidget);
    await tester.tap(find.byIcon(Icons.remove_circle_outline_rounded));
    await tester.pumpAndSettle();
    expect(provider.taskById('late')!.isMissed, isFalse, reason: '되돌리면 다시 기한 지남으로');
    expect(provider.overdueTasks.map((t) => t.id), contains('late'));
  });

  testWidgets('프로젝트 업무는 [기한 변경] 없이 [완료]·[미완료 처리]만, [완료]는 완료 보고', (tester) async {
    await _boot(tester);
    final now = DateTime.now();
    _provider(tester).addTask(TaskItem(
      id: 'pt_9', title: '배정 업무', createdAt: now,
      dueDate: now.subtract(const Duration(hours: 1)),
      project: const ProjectLink(roomId: 'r', roomName: '신제품', projectName: '디자인', taskId: '9'),
    ));
    await tester.tap(find.text('오늘 할일'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기한 지남'));
    await tester.pumpAndSettle();
    expect(find.text('배정 업무'), findsOneWidget);
    expect(find.text('기한 변경'), findsNothing);
    expect(find.text('미완료 처리'), findsOneWidget);
    expect(_doneButton, findsOneWidget);
    expect(find.text('프로젝트 업무의 마감은 팀장만 바꿀 수 있어요'), findsOneWidget);

    // [완료]는 기존 검토 흐름: 완료 보고하면 검토중이 되어 기한 지남에서 빠진다
    await tester.tap(_doneButton);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(
        of: find.byType(AlertDialog), matching: find.widgetWithText(FilledButton, '완료')));
    await tester.pumpAndSettle();
    expect(_provider(tester).taskById('pt_9')!.project!.reviewRequested, isTrue);
    expect(find.text('배정 업무'), findsNothing);
  });

  testWidgets('[완료]하면 "완료(기한 후)"로 저장돼 [완료된 일들]로 가고, 실행 취소하면 기한 지남으로 돌아온다', (tester) async {
    await _boot(tester);
    final now = DateTime.now();
    final provider = _provider(tester);
    provider.addTask(TaskItem(id: 'late', title: '어제 보고서', createdAt: now,
        dueDate: DateTime(now.year, now.month, now.day - 1, 10)));
    await tester.tap(find.text('오늘 할일'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('기한 지남'));
    await tester.pumpAndSettle();
    await tester.tap(_doneButton);
    await tester.pump();
    final done = provider.taskById('late')!;
    expect([done.isDone, done.isMissed, done.completedLate], [true, false, true]);
    expect(provider.archivedTasks.first.id, 'late');
    expect(taskFromJson(taskToJson(done)).completedLate, isTrue, reason: '저장했다 읽어도 기한 후 완료');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.tap(find.text('실행 취소'));
    await tester.pumpAndSettle();
    expect(provider.overdueTasks.map((t) => t.id), contains('late'));
  });

  testWidgets('기한 후 완료는 [완료된 일들]에 "완료 · 기한 후", 기한 전에 끝낸 일은 "완료"로 보인다', (tester) async {
    await _boot(tester);
    final now = DateTime.now();
    final provider = _provider(tester);
    provider.addTask(TaskItem(id: 'late', title: '늦은 일', createdAt: now,
        dueDate: DateTime(now.year, now.month, now.day - 1, 10)));
    provider.addTask(TaskItem(id: 'ontime', title: '제때 한 일', createdAt: now,
        dueDate: now.add(const Duration(days: 2))));
    provider.toggleTask('late');
    provider.toggleTask('ontime');
    expect(provider.taskById('late')!.completedLate, isTrue);
    expect(provider.taskById('ontime')!.completedLate, isFalse);
    Navigator.of(tester.element(find.byType(Scaffold).first))
        .push(MaterialPageRoute<void>(builder: (_) => const ArchiveView()));
    await tester.pumpAndSettle();
    expect(find.textContaining(RegExp(r'^\d+:\d+ 완료 · 기한 후$')), findsOneWidget);
    // 되돌리면 기한 후 표시도 지워진다
    provider.toggleTask('late');
    expect(provider.taskById('late')!.completedLate, isFalse);
  });

  testWidgets('진행률 막대는 세부 체크리스트가 있는 할 일에만 보인다', (tester) async {
    await _boot(tester);
    final provider = _provider(tester);
    final withSubs = provider.activeTasks.where((t) => t.subTasks.isNotEmpty).length;
    expect(withSubs, greaterThan(0));
    expect(provider.activeTasks.length, greaterThan(withSubs), reason: '체크리스트 없는 할 일도 있어야 비교된다');
    await tester.tap(find.text('오늘 할일'));
    await tester.pumpAndSettle();
    expect(find.byType(TaskProgressBar), findsNWidgets(withSubs));
  });
}
