import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_amatda/data/local_store.dart';
import 'package:flutter_application_amatda/models/note.dart';
import 'package:flutter_application_amatda/models/sub_task.dart';
import 'package:flutter_application_amatda/models/task_item.dart';
import 'package:flutter_application_amatda/providers/room_provider.dart';
import 'package:flutter_application_amatda/providers/routine_provider.dart';
import 'package:flutter_application_amatda/providers/theme_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('새 계정은 빈 상태로 시작하고, 저장소 없이 만들면 샘플 데이터', () async {
    final store = (await LocalStore.open()).forUser('u_new');
    expect(RoomProvider(store: store).rooms, isEmpty);
    expect(RoutineProvider(store: store).routines, isEmpty);
    expect(RoomProvider().rooms, isNotEmpty);
  });

  test('계정마다 데이터가 따로 저장되고, 예전 기기 데이터와도 섞이지 않는다', () async {
    final root = await LocalStore.open();
    RoomProvider(store: root.forUser('u_a')).addRoom(RoomProvider().rooms.first);
    expect(RoomProvider(store: root.forUser('u_a')).rooms, hasLength(1));
    expect(RoomProvider(store: root.forUser('u_b')).rooms, isEmpty);
    expect(root.loadRooms(), isNull);
  });

  test('할 일·세부 항목·메모 변경이 다시 열어도 유지된다', () async {
    final store = await LocalStore.open();
    final provider = RoomProvider(store: store);
    final due = DateTime(2026, 10, 7, 18, 30);
    provider.addTask(TaskItem(
      id: 'task_new',
      title: '새 할 일',
      dueDate: due,
      roomId: 'room_001',
      createdAt: DateTime(2026, 10, 5),
    ));
    provider.addSubTask('task_new', const SubTask(id: 's1', title: '세부'));
    provider.addNote(
      'task_new',
      Note(id: 'n1', content: '메모', createdAt: DateTime(2026, 10, 5, 9)),
    );
    provider.toggleTask('task_new');
    provider.deleteRoom('room_003');

    final reopened = RoomProvider(store: await LocalStore.open());
    final task = reopened.taskById('task_new')!;
    expect(task.title, '새 할 일');
    expect(task.dueDate, due);
    expect(task.isDone, isTrue);
    expect(task.completedAt, isNotNull);
    expect(task.subTasks.single.title, '세부');
    expect(task.notes.single.content, '메모');
    expect(reopened.roomById('room_003'), isNull);
  });

  test('데이터 초기화하면 모두 지워진다', () async {
    final sample = RoomProvider();
    final provider = RoomProvider(store: await LocalStore.open())
      ..replaceAll(sample.rooms, sample.tasks);
    provider.clearAll();
    final reopened = RoomProvider(store: await LocalStore.open());
    expect(reopened.rooms, isEmpty);
    expect(reopened.tasks, isEmpty);
  });

  test('테마 설정이 저장된다', () async {
    ThemeProvider(store: await LocalStore.open()).setThemeMode(ThemeMode.dark);
    final reopened = ThemeProvider(store: await LocalStore.open());
    expect(reopened.themeMode, ThemeMode.dark);
  });

  test('저장된 데이터가 깨져 있으면 빈 상태로 시작한다', () async {
    SharedPreferences.setMockInitialValues({'tasks_v1': '{깨진 데이터'});
    final provider = RoomProvider(store: await LocalStore.open());
    expect(provider.tasks, isEmpty);
  });
}
