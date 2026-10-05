import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_amatda/data/local_store.dart';
import 'package:flutter_application_amatda/models/task_item.dart';
import 'package:flutter_application_amatda/models/task_reminder.dart';
import 'package:flutter_application_amatda/models/telegram_room.dart';
import 'package:flutter_application_amatda/providers/room_provider.dart';
import 'package:flutter_application_amatda/services/reminder_checker.dart';
import 'package:flutter_application_amatda/utils/links.dart';

TaskItem _task(String id, {DateTime? due, TaskReminder? reminder}) => TaskItem(
      id: id,
      title: id,
      dueDate: due,
      reminder: reminder,
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
      final p = RoomProvider(store: store);
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
            reminder: const TaskReminder(amount: 30, unit: ReminderUnit.minute)),
        _task('later',
            due: DateTime(2026, 10, 20),
            reminder: const TaskReminder(amount: 1, unit: ReminderUnit.week)),
        _task('no-reminder', due: DateTime(2026, 10, 5, 12, 5)),
      ];
      final due = collectDueReminders(
          tasks: tasks, rooms: const [], now: now, fired: {});
      expect(due.map((r) => r.title), ['soon']);
      expect(due.single.body, '마감까지 20분 남았어요');

      final again = collectDueReminders(
          tasks: tasks, rooms: const [], now: now, fired: {due.single.key});
      expect(again, isEmpty);
    });

    test('완료했거나 마감이 한참 지난 할 일은 울리지 않는다', () {
      const r = TaskReminder(amount: 1, unit: ReminderUnit.day);
      final done = _task('done', due: DateTime(2026, 10, 6), reminder: r)
          .markDone(true);
      final stale = _task('stale', due: DateTime(2026, 10, 3), reminder: r);
      expect(
        collectDueReminders(
            tasks: [done, stale], rooms: const [], now: now, fired: {}),
        isEmpty,
      );
    });

    test('업무방 마감 리마인더도 울린다', () {
      final room = TelegramRoom(
        id: 'r1',
        name: '기획',
        type: TelegramRoomType.group,
        inviteLink: '',
        lastActivityAt: now,
        dueDate: DateTime(2026, 10, 5, 12, 30),
        reminderOption: ReminderOption.oneHourBefore,
      );
      final due = collectDueReminders(
          tasks: const [], rooms: [room], now: now, fired: {});
      expect(due.single.title, '기획 업무방');
    });
  });

  test('업무 링크와 리마인드가 저장 후에도 유지된다', () async {
    final p = RoomProvider(store: await LocalStore.open());
    final room = p.rooms.first;
    p.updateRoom(room.copyWithEdits(
      name: '이름 변경',
      inviteLink: room.inviteLink,
      workLinks: const ['https://notion.so/a', 'https://blog.naver.com/b'],
      reminderOption: ReminderOption.none,
    ));
    final task = p.activeTasks.first;
    p.updateTask(task.copyWithEdits(
      title: task.title,
      dueDate: DateTime(2026, 11, 1, 9),
      reminder: const TaskReminder(amount: 2, unit: ReminderUnit.week),
    ));

    final reopened = RoomProvider(store: await LocalStore.open());
    final savedRoom = reopened.roomById(room.id)!;
    expect(savedRoom.name, '이름 변경');
    expect(savedRoom.workLinks, hasLength(2));
    expect(reopened.taskById(task.id)!.reminder!.label, '2주 전');
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
}
