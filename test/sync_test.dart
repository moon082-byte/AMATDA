import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_amatda/data/local_store.dart';
import 'package:flutter_application_amatda/data/model_json.dart';
import 'package:flutter_application_amatda/data/sync_records.dart';
import 'package:flutter_application_amatda/data/sync_shadow.dart';
import 'package:flutter_application_amatda/models/note.dart';
import 'package:flutter_application_amatda/models/sub_task.dart';
import 'package:flutter_application_amatda/providers/room_provider.dart';
import 'package:flutter_application_amatda/providers/routine_provider.dart';
import 'package:flutter_application_amatda/services/api_client.dart';
import 'package:flutter_application_amatda/services/sync_service.dart';
import 'support/fake_server.dart';

/// 한 기기: 계정 저장소 + 데이터 + 동기화
class _Device {
  final RoomProvider rooms;
  final RoutineProvider routines;
  final SyncService sync;

  _Device._(this.rooms, this.routines, this.sync);

  static Future<_Device> open(FakeServer server, String name) async {
    final store = (await LocalStore.open()).forUser('u_1:$name');
    final rooms = RoomProvider(store: store);
    final routines = RoutineProvider(store: store);
    final api = ApiClient(
        baseUrl: 'https://api.test', token: () => 'tok', client: server.client);
    return _Device._(rooms, routines,
        SyncService(api: api, store: store, rooms: rooms, routines: routines));
  }
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('앱 데이터 ↔ 서버 행 변환이 내용을 그대로 지킨다', () {
    final sample = RoomProvider();
    final routines = RoutineProvider().routines;
    final records = toRecords(sample.rooms, sample.tasks, routines);
    expect(records['sub_tasks'], hasLength(3));
    expect(records['notes']!.values.single.parentId, 'task_001');
    expect(records['tasks']!['task_001']!.parentId, 'room_001');

    final back = fromRecords(records);
    String enc(Object o) => jsonEncode(o);
    expect(enc(back.rooms.map(roomToJson).toList()),
        enc(sample.rooms.map(roomToJson).toList()));
    expect(enc(back.tasks.map(taskToJson).toList()),
        enc(sample.tasks.map(taskToJson).toList()));
    expect(enc(back.routines.map(routineToJson).toList()),
        enc(routines.map(routineToJson).toList()));
  });

  test('바뀐 행과 지운 행만 골라낸다', () {
    final sample = RoomProvider();
    final shadow = toRecords(sample.rooms, sample.tasks, const []);
    sample.toggleSubTask('task_001', 'sub_002');
    sample.deleteRoom('room_003');
    final diff = diffRecords(
        toRecords(sample.rooms, sample.tasks, const []), shadow, max: 500);
    expect(diff['sub_tasks']!.single.id, 'sub_002');
    expect(diff['rooms']!.single.deleted, isTrue);
    expect(diff['tasks'], isEmpty);
    expect(diffRecords(toRecords(sample.rooms, sample.tasks, const []),
            emptyRecordSet(), max: 2)
        .values
        .fold(0, (n, l) => n + l.length), 2);
  });

  test('PC에서 바꾼 것이 휴대폰에 반영되고, 삭제도 전달된다', () async {
    final server = FakeServer();
    final pc = await _Device.open(server, 'pc');
    final phone = await _Device.open(server, 'phone');

    final sample = RoomProvider();
    pc.rooms.replaceAll(sample.rooms, sample.tasks);
    await pc.sync.syncNow();
    expect(server.ids('tasks'), containsAll(['task_001', 'task_003']));

    await phone.sync.syncNow();
    expect(phone.rooms.taskById('task_001')!.subTasks, hasLength(3));
    expect(phone.rooms.rooms.map((r) => r.id), sample.rooms.map((r) => r.id));

    // 휴대폰: 세부 항목 지우기, 메모 추가 / PC: 받아오기
    phone.rooms.deleteSubTask('task_001', 'sub_003');
    phone.rooms.addNote('task_001',
        Note(id: 'note_new', content: '휴대폰 메모', createdAt: DateTime(2026, 10, 7)));
    await phone.sync.syncNow();
    await pc.sync.syncNow();
    final task = pc.rooms.taskById('task_001')!;
    expect(task.subTasks.map((s) => s.id), ['sub_001', 'sub_002']);
    expect(task.notes.last.content, '휴대폰 메모');

    // PC: 업무방 삭제 → 휴대폰에서도 사라진다
    pc.rooms.deleteRoom('room_003');
    await pc.sync.syncNow();
    await phone.sync.syncNow();
    expect(phone.rooms.roomById('room_003'), isNull);
    expect(pc.sync.error, isNull);
    expect(pc.sync.lastSyncedAt, isNotNull);
  });

  test('같은 항목을 두 기기에서 고치면 나중에 저장한 쪽이 이긴다', () async {
    final server = FakeServer();
    final pc = await _Device.open(server, 'pc');
    final phone = await _Device.open(server, 'phone');
    pc.rooms.replaceAll(const [], RoomProvider().tasks.take(1).toList());
    await pc.sync.syncNow();
    await phone.sync.syncNow();

    final original = pc.rooms.taskById('task_001')!;
    pc.rooms.updateTask(original.copyWithEdits(
        title: 'PC가 고친 제목', dueDate: original.dueDate, reminders: original.reminders));
    pc.rooms.addSubTask('task_001', const SubTask(id: 's_pc', title: 'PC'));
    phone.rooms.toggleTask('task_001'); // 같은 할 일 행을 휴대폰도 고침
    await pc.sync.syncNow();
    await phone.sync.syncNow(); // 휴대폰이 나중에 도착
    await pc.sync.syncNow();
    final onPc = pc.rooms.taskById('task_001')!;
    expect(onPc.isDone, isTrue);
    expect(onPc.title, original.title, reason: '같은 행은 나중에 저장한 휴대폰 것이 남는다');
    expect(phone.rooms.taskById('task_001')!.subTasks.last.id, 's_pc',
        reason: '서로 다른 행(세부 항목)은 둘 다 남는다');
  });

  test('인터넷이 끊겨도 이 기기 데이터는 남고, 다시 연결되면 올린다', () async {
    final server = FakeServer()..offline = true;
    final pc = await _Device.open(server, 'pc');
    pc.routines.replaceAll(RoutineProvider().routines);
    await pc.sync.syncNow();
    expect(pc.sync.error, isNotNull);
    expect(pc.routines.routines, hasLength(3));

    server.offline = false;
    await pc.sync.syncNow();
    expect(pc.sync.error, isNull);
    expect(server.ids('routines'), hasLength(3));

    // 앱을 다시 열어도(동기화 상태 저장) 다시 올리지 않는다
    final calls = server.version;
    final reopened = await _Device.open(server, 'pc');
    await reopened.sync.syncNow();
    expect(server.version, calls);
    expect(reopened.routines.routines, hasLength(3));
  });
}
