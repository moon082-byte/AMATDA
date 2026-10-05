import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_amatda/data/local_store.dart';
import 'package:flutter_application_amatda/models/note.dart';
import 'package:flutter_application_amatda/models/sub_task.dart';
import 'package:flutter_application_amatda/models/task_item.dart';
import 'package:flutter_application_amatda/providers/room_provider.dart';
import 'package:flutter_application_amatda/providers/theme_provider.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('처음 실행하면 샘플 데이터로 시작한다', () async {
    final provider = RoomProvider(store: await LocalStore.open());
    expect(provider.rooms, isNotEmpty);
    expect(provider.tasks, isNotEmpty);
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

  test('초기화하면 샘플 데이터로 되돌아간다', () async {
    final provider = RoomProvider(store: await LocalStore.open());
    for (final room in List.of(provider.rooms)) {
      provider.deleteRoom(room.id);
    }
    expect(provider.rooms, isEmpty);

    provider.resetToSample();
    final reopened = RoomProvider(store: await LocalStore.open());
    expect(reopened.rooms, isNotEmpty);
  });

  test('테마 설정이 저장된다', () async {
    ThemeProvider(store: await LocalStore.open()).setThemeMode(ThemeMode.dark);
    final reopened = ThemeProvider(store: await LocalStore.open());
    expect(reopened.themeMode, ThemeMode.dark);
  });

  test('저장된 데이터가 깨져 있으면 샘플 데이터로 시작한다', () async {
    SharedPreferences.setMockInitialValues({'tasks_v1': '{깨진 데이터'});
    final provider = RoomProvider(store: await LocalStore.open());
    expect(provider.tasks, isNotEmpty);
  });
}
