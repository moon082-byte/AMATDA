import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_amatda/data/local_store.dart';
import 'package:flutter_application_amatda/models/task_item.dart';
import 'package:flutter_application_amatda/models/task_reminder.dart';
import 'package:flutter_application_amatda/models/telegram_room.dart';
import 'package:flutter_application_amatda/providers/room_provider.dart';
import 'package:flutter_application_amatda/services/reminder_checker.dart';
import 'package:flutter_application_amatda/utils/date_format.dart';
import 'package:flutter_application_amatda/utils/links.dart';
import 'package:flutter_application_amatda/utils/nearest_due.dart';

TaskItem _task(String id,
        {DateTime? due, List<DateTime> remindAt = const []}) =>
    TaskItem(
      id: id,
      title: id,
      dueDate: due,
      remindAt: remindAt,
      createdAt: DateTime(2026, 10, 1),
    );

RoomProvider _providerWith(List<String> ids) {
  final p = RoomProvider();
  for (final t in List.of(p.tasks)) {
    p.deleteTask(t.id);
  }
  for (final id in ids) {
    p.addTask(_task(id));
  }
  return p;
}

List<String> _ids(RoomProvider p) => [for (final t in p.activeTasks) t.id];

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('드래그 순서 변경', () {
    test('아래로 옮기기 / 위로 옮기기 / 맨 끝으로 옮기기', () {
      final p = _providerWith(['a', 'b', 'c', 'd']);
      p.reorderTasks(_ids(p), 0, 2); // a를 세 번째 자리로
      expect(_ids(p), ['b', 'c', 'a', 'd']);
      p.reorderTasks(_ids(p), 3, 0); // d를 맨 앞으로
      expect(_ids(p), ['d', 'b', 'c', 'a']);
      p.reorderTasks(_ids(p), 0, 3); // d를 맨 끝으로
      expect(_ids(p), ['b', 'c', 'a', 'd']);
    });

    test('완료된 항목이 섞여 있어도 보이는 목록 기준으로 옮긴다', () {
      final p = _providerWith(['a', 'b', 'c']);
      p.toggleTask('b'); // b 완료 → 보이는 목록: a, c
      p.reorderTasks(_ids(p), 1, 0); // c를 맨 앞으로
      expect(_ids(p), ['c', 'a']);
    });

    test('바꾼 순서가 저장된다', () async {
      final store = await LocalStore.open();
      final p = RoomProvider(store: store)
        ..replaceAll(const [], _providerWith(['a', 'b', 'c']).tasks);
      final before = _ids(p);
      p.reorderTasks(before, before.length - 1, 0);
      expect(_ids(RoomProvider(store: await LocalStore.open())).first,
          before.last);
    });
  });

  test('실수로 완료한 할 일을 되돌리면 원래 자리로 돌아온다', () {
    final p = _providerWith(['a', 'b', 'c']);
    p.toggleTask('b');
    expect(_ids(p), ['a', 'c']);
    p.toggleTask('b');
    expect(_ids(p), ['a', 'b', 'c']);
    expect(p.taskById('b')!.completedAt, isNull);
  });

  group('리마인드', () {
    final now = DateTime(2026, 10, 5, 12);

    test('알림 시각이 지난 것만 한 번씩 울린다', () {
      final tasks = [
        _task('soon',
            due: DateTime(2026, 10, 5, 12, 20),
            remindAt: [DateTime(2026, 10, 5, 11, 50)]),
        _task('later',
            due: DateTime(2026, 10, 20),
            remindAt: [DateTime(2026, 10, 13)]),
        _task('no-reminder', due: DateTime(2026, 10, 5, 12, 5)),
      ];
      final due = collectDueReminders(
          tasks: tasks, now: now, fired: {});
      expect(due.map((r) => r.title), ['soon']);
      expect(due.single.body, '마감까지 20분 남았어요');

      final again = collectDueReminders(
          tasks: tasks, now: now, fired: {due.single.key});
      expect(again, isEmpty);
    });

    test('알림을 여러 개 걸면 시각마다 따로 울린다', () {
      final t = _task('multi', due: DateTime(2026, 10, 5, 13), remindAt: [
        DateTime(2026, 10, 5, 11), // 지남
        DateTime(2026, 10, 5, 12, 30), // 아직
      ]);
      final first = collectDueReminders(
          tasks: [t], now: now, fired: {});
      expect(first, hasLength(1));

      final fired = {...first.single.alsoCovers, first.single.key};
      final later = collectDueReminders(
          tasks: [t],
          now: DateTime(2026, 10, 5, 12, 31),
          fired: fired);
      expect(later, hasLength(1), reason: '12:30 알림이 다시 울려야 한다');
      expect(later.single.key, isNot(first.single.key));
    });

    test('한꺼번에 지난 알림 여러 개는 한 번만 알린다', () {
      final t = _task('missed', due: DateTime(2026, 10, 5, 12, 10), remindAt: [
        DateTime(2026, 10, 4, 12, 10),
        DateTime(2026, 10, 5, 11, 10),
        DateTime(2026, 10, 5, 11, 40),
      ]);
      final due = collectDueReminders(
          tasks: [t], now: now, fired: {});
      expect(due, hasLength(1));
      expect(due.single.alsoCovers, hasLength(3));
    });

    test('완료했거나 마감이 한참 지난 할 일은 울리지 않는다', () {
      final done = _task('done',
              due: DateTime(2026, 10, 6), remindAt: [DateTime(2026, 10, 5)])
          .markDone(true);
      final stale = _task('stale',
          due: DateTime(2026, 10, 3), remindAt: [DateTime(2026, 10, 2)]);
      final oldFree = _task('old', remindAt: [DateTime(2026, 10, 4, 23)]);
      expect(
        collectDueReminders(
            tasks: [done, stale, oldFree], now: now, fired: {}),
        isEmpty,
      );
    });

    test('마감이 없어도 고른 시각에 울린다', () {
      final t = _task('free', remindAt: [DateTime(2026, 10, 5, 11, 30)]);
      final due = collectDueReminders(tasks: [t], now: now, fired: {});
      expect(due.single.title, 'free');
      expect(due.single.body, '리마인더 시각이에요');
    });

    test('업무방에서는 마감이 가장 가까운 미완료 할 일을 보여준다', () {
      final tasks = [
        _task('later', due: DateTime(2026, 10, 9)),
        _task('done', due: DateTime(2026, 10, 4)).markDone(true),
        _task('soon', due: DateTime(2026, 10, 6)),
        _task('none'),
      ];
      expect(nearestDueTask(tasks)?.title, 'soon');
      expect(nearestDueTask([_task('none')]), isNull);
    });
  });

  test('업무 링크와 리마인드가 저장 후에도 유지된다', () async {
    final sample = RoomProvider(); // 저장소 없이 만들면 샘플 데이터
    final p = RoomProvider(store: await LocalStore.open())
      ..replaceAll(sample.rooms, sample.tasks);
    final room = p.rooms.first;
    p.updateRoom(room.copyWithEdits(
      name: '이름 변경',
      type: TelegramRoomType.channel,
      memberCount: 42,
      inviteLink: room.inviteLink,
      workLinks: const ['https://notion.so/a', 'https://blog.naver.com/b'],
    ));
    final task = p.activeTasks.first;
    p.updateTask(task.copyWithEdits(
      title: task.title,
      dueDate: DateTime(2026, 11, 1, 9),
      remindAt: [DateTime(2026, 10, 18, 9), DateTime(2026, 11, 1, 8, 30)],
    ));

    final reopened = RoomProvider(store: await LocalStore.open());
    final savedRoom = reopened.roomById(room.id)!;
    expect(savedRoom.name, '이름 변경');
    expect(savedRoom.workLinks, hasLength(2));
    expect(savedRoom.type, TelegramRoomType.channel);
    expect(savedRoom.memberCount, 42);
    expect(
      reopened.taskById(task.id)!.remindAt,
      [DateTime(2026, 10, 18, 9), DateTime(2026, 11, 1, 8, 30)],
    );
  });

  test('링크 주소 다듬기와 서비스 이름', () {
    expect(normalizeUrl(' notion.so/abc '), 'https://notion.so/abc');
    expect(normalizeUrl('https://t.me/x'), 'https://t.me/x');
    expect(normalizeUrl(''), '');
    expect(linkService('https://open.kakao.com/o/x').$1, '카카오톡');
    expect(linkService('https://www.notion.so/x').$1, '노션');
    expect(linkService('https://example.com').$1, '웹 링크');
    expect(linkHost('https://www.notion.so/x'), 'notion.so');
  });

  test('예전 형식(리마인드 1개, 업무방 선택지)도 새 형식으로 읽는다', () async {
    SharedPreferences.setMockInitialValues({
      'rooms_v1': '[{"id":"r","name":"방","type":"group","inviteLink":"",'
          '"lastActivityAt":"2026-10-01T09:00:00.000","dueDate":"2026-10-09T18:00:00.000",'
          '"reminderOption":"oneHourBefore"}]',
      'tasks_v1': '[{"id":"t","title":"할 일","createdAt":"2026-10-01T09:00:00.000",'
          '"dueDate":"2026-10-09T18:00:00.000","reminder":{"amount":2,"unit":"day"}},'
          '{"id":"t2","title":"할 일2","createdAt":"2026-10-01T09:00:00.000",'
          '"dueDate":"2026-10-09T18:00:00.000",'
          '"reminders":[{"amount":30,"unit":"minute"},{"amount":1,"unit":"day"}],'
          '"subTasks":[{"id":"s","title":"세부","reminders":[{"amount":1,"unit":"hour"}]}]}]',
    });
    final p = RoomProvider(store: await LocalStore.open());
    expect(p.roomById('r')!.reminders.single.label, '1시간 전');
    // 예전 "마감 N 전" 리마인더는 실제 알림 시각(마감 − N)으로 바뀐다
    expect(p.taskById('t')!.remindAt, [DateTime(2026, 10, 7, 18)]);
    final t2 = p.taskById('t2')!;
    expect(t2.remindAt, [DateTime(2026, 10, 8, 18), DateTime(2026, 10, 9, 17, 30)]);
    expect(t2.subTasks.single.remindAt, [DateTime(2026, 10, 9, 17)]);
  });

  test('리마인드 요약 라벨', () {
    expect(remindAtSummary(const []), '');
    final next = DateTime(2030, 1, 7, 13);
    expect(
      remindAtSummary([DateTime(2030, 1, 8, 9), next, DateTime(2030, 1, 6)],
          now: DateTime(2030, 1, 7, 12)),
      '${formatDateWithWeekday(next)} 13:00 외 2',
    );
    expect(remindersSummary(const []), '');
    expect(
      remindersSummary(const [
        TaskReminder(amount: 30, unit: ReminderUnit.minute),
        TaskReminder(amount: 1, unit: ReminderUnit.day),
      ]),
      '1일 전 외 1',
    );
  });
}
