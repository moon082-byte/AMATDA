import 'dart:convert';
import '../models/routine.dart';
import '../models/task_item.dart';
import '../models/telegram_room.dart';
import 'model_json.dart';

/// 서버 동기화용 한 행. 서버 표(rooms, tasks, sub_tasks, notes, routines)의 행과 같은 모양이다.
class SyncRecord {
  final String id;

  /// 할 일 → 업무방, 세부 항목·메모 → 할 일
  final String? parentId;

  /// 화면에 보이는 순서
  final int position;

  /// 나머지 내용 (JSON 문자열)
  final String data;
  final bool deleted;

  const SyncRecord({
    required this.id,
    this.parentId,
    this.position = 0,
    required this.data,
    this.deleted = false,
  });

  factory SyncRecord.fromJson(Map<String, dynamic> j) => SyncRecord(
        id: j['id'] as String,
        parentId: j['parentId'] as String?,
        position: (j['position'] as num?)?.toInt() ?? 0,
        data: j['data'] as String,
        deleted: j['deleted'] == true,
      );

  Map<String, Object?> toJson() => {
        'id': id,
        'parentId': parentId,
        'position': position,
        'data': data,
        if (deleted) 'deleted': true,
      };

  SyncRecord asDeleted() => SyncRecord(
      id: id, parentId: parentId, position: position, data: data, deleted: true);

  /// 내용이 같은지 비교용
  bool sameAs(SyncRecord other) =>
      parentId == other.parentId &&
      position == other.position &&
      data == other.data &&
      deleted == other.deleted;
}

const syncTables = ['rooms', 'tasks', 'sub_tasks', 'notes', 'routines'];

/// 표 이름 → (id → 행)
typedef RecordSet = Map<String, Map<String, SyncRecord>>;

RecordSet emptyRecordSet() => {for (final t in syncTables) t: {}};

/// 앱 데이터 → 서버 행들. 세부 항목·메모는 할 일에서 떼어 따로 저장한다.
RecordSet toRecords(
  List<TelegramRoom> rooms,
  List<TaskItem> tasks,
  List<Routine> routines,
) {
  final set = emptyRecordSet();
  void put(String table, String id, int position, Map<String, Object?> data,
      [String? parentId]) {
    set[table]![id] = SyncRecord(
        id: id, parentId: parentId, position: position, data: jsonEncode(data));
  }

  for (final (i, r) in rooms.indexed) {
    put('rooms', r.id, i, roomToJson(r)..remove('id'));
  }
  for (final (i, t) in tasks.indexed) {
    final data = taskToJson(t)
      ..remove('id')
      ..remove('roomId')
      ..remove('subTasks')
      ..remove('notes');
    put('tasks', t.id, i, data, t.roomId);
    for (final (j, s) in t.subTasks.indexed) {
      put('sub_tasks', s.id, j, {'title': s.title, 'isDone': s.isDone}, t.id);
    }
    for (final (j, n) in t.notes.indexed) {
      put('notes', n.id, j,
          {'content': n.content, 'createdAt': n.createdAt.toIso8601String()}, t.id);
    }
  }
  for (final (i, r) in routines.indexed) {
    put('routines', r.id, i, routineToJson(r)..remove('id'));
  }
  return set;
}

/// 서버 행들 → 앱 데이터 (순서대로 정렬, 부모가 없는 세부 항목·메모는 뺀다)
({List<TelegramRoom> rooms, List<TaskItem> tasks, List<Routine> routines})
    fromRecords(RecordSet set) {
  List<SyncRecord> sorted(String table) => set[table]!.values
      .where((r) => !r.deleted)
      .toList()
    ..sort((a, b) => a.position != b.position
        ? a.position.compareTo(b.position)
        : a.id.compareTo(b.id));
  Map<String, dynamic> decode(SyncRecord r) =>
      {...jsonDecode(r.data) as Map<String, dynamic>, 'id': r.id};
  Map<String, List<Map<String, dynamic>>> children(String table) {
    final byParent = <String, List<Map<String, dynamic>>>{};
    for (final r in sorted(table)) {
      byParent.putIfAbsent(r.parentId ?? '', () => []).add(decode(r));
    }
    return byParent;
  }

  final subTasks = children('sub_tasks');
  final notes = children('notes');
  return (
    rooms: [for (final r in sorted('rooms')) roomFromJson(decode(r))],
    tasks: [
      for (final r in sorted('tasks'))
        taskFromJson({
          ...decode(r),
          'roomId': r.parentId,
          'subTasks': subTasks[r.id] ?? const [],
          'notes': notes[r.id] ?? const [],
        }),
    ],
    routines: [for (final r in sorted('routines')) routineFromJson(decode(r))],
  );
}
