import 'package:flutter/foundation.dart';
import '../data/local_store.dart';
import '../data/sample_data.dart';
import '../models/note.dart';
import '../models/sub_task.dart';
import '../models/task_item.dart';
import '../models/telegram_room.dart';

part 'room_provider_details.dart';

/// 업무방, 할 일, 하위 체크리스트, 메모 상태를 관리.
/// [store](계정별 저장소)가 있으면 변경될 때마다 저장하고, 새 계정은 빈 상태로 시작한다.
/// [store]가 없으면(테스트·미리보기) 샘플 데이터로 시작한다.
/// 할 일 목록의 순서가 곧 화면 표시 순서다(드래그로 변경).
class RoomProvider extends ChangeNotifier {
  final LocalStore? _store;
  final List<TelegramRoom> _rooms;
  final List<TaskItem> _tasks;

  RoomProvider({LocalStore? store})
      : _store = store,
        _rooms = store == null ? buildMockTelegramRooms() : store.loadRooms() ?? [],
        _tasks = store == null ? buildMockTaskItems() : store.loadTasks() ?? [];

  /// 상태가 바뀔 때마다 저장소에도 기록한다
  @override
  void notifyListeners() {
    _store?.saveData(_rooms, _tasks);
    super.notifyListeners();
  }

  /// 모든 업무방과 할 일을 지운다 (로그인한 모든 기기에 반영된다)
  void clearAll() => replaceAll(const [], const []);

  /// 목록 전체를 바꾼다 (다른 기기에서 받은 데이터 반영)
  void replaceAll(List<TelegramRoom> rooms, List<TaskItem> tasks) {
    _rooms
      ..clear()
      ..addAll(rooms);
    _tasks
      ..clear()
      ..addAll(tasks);
    notifyListeners();
  }

  /// 없는 항목만 덧붙이고 개수를 돌려준다 (같은 id면 지금 것을 남긴다)
  int mergeMissing(List<TelegramRoom> rooms, List<TaskItem> tasks) {
    final newRooms = rooms.where((r) => roomById(r.id) == null).toList();
    final newTasks = tasks.where((t) => taskById(t.id) == null).toList();
    _rooms.addAll(newRooms);
    _tasks.addAll(newTasks);
    notifyListeners();
    return newRooms.length + newTasks.length;
  }

  List<TelegramRoom> get rooms => List.unmodifiable(_rooms);
  List<TaskItem> get tasks => List.unmodifiable(_tasks);

  /// 완료되지 않은(진행 중인) 할 일만
  List<TaskItem> get activeTasks => _tasks.where((t) => !t.isDone).toList();

  /// 완료된 할 일을 완료 시각 최신순으로 정렬한 아카이브 목록
  List<TaskItem> get archivedTasks {
    final done = _tasks.where((t) => t.isDone).toList();
    done.sort(
      (a, b) =>
          (b.completedAt ?? b.createdAt).compareTo(a.completedAt ?? a.createdAt),
    );
    return done;
  }

  int get totalPendingCount => activeTasks.length;
  int get totalCompletedCount => _tasks.where((t) => t.isDone).length;

  TelegramRoom? roomById(String id) =>
      _rooms.where((r) => r.id == id).firstOrNull;

  TaskItem? taskById(String id) => _tasks.where((t) => t.id == id).firstOrNull;

  List<TaskItem> tasksForRoom(String roomId) =>
      _tasks.where((t) => t.roomId == roomId).toList();

  /// 방에 속한, 아직 완료되지 않은 할 일만
  List<TaskItem> activeTasksForRoom(String roomId) =>
      _tasks.where((t) => t.roomId == roomId && !t.isDone).toList();

  int pendingCountForRoom(String roomId) =>
      activeTasksForRoom(roomId).length;

  void addRoom(TelegramRoom room) {
    _rooms.add(room);
    notifyListeners();
  }

  void updateRoom(TelegramRoom updated) {
    final index = _rooms.indexWhere((r) => r.id == updated.id);
    if (index == -1) return;
    _rooms[index] = updated;
    notifyListeners();
  }

  /// 방과 그 방에 속한 할 일을 모두 삭제한다
  void deleteRoom(String roomId) {
    _rooms.removeWhere((r) => r.id == roomId);
    _tasks.removeWhere((t) => t.roomId == roomId);
    notifyListeners();
  }

  void addTask(TaskItem task) {
    _tasks.add(task);
    notifyListeners();
  }

  void updateTask(TaskItem updated) => _edit(updated.id, (_) => updated);

  void deleteTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }

  /// 완료/미완료를 바꾼다. 목록 내 위치는 그대로라 되돌리면 원래 자리로 돌아온다.
  void toggleTask(String taskId) => _edit(taskId, (t) => t.markDone(!t.isDone));

  /// 화면에 보이는 목록([visibleIds]) 안에서 드래그로 순서를 바꾼다.
  /// [newIndex]는 옮긴 항목을 뺀 뒤 기준의 최종 위치다(onReorderItem 규칙).
  void reorderTasks(List<String> visibleIds, int oldIndex, int newIndex) {
    if (oldIndex == newIndex) return;
    final ids = List.of(visibleIds);
    final movedId = ids.removeAt(oldIndex);
    ids.insert(newIndex, movedId);

    final moved = _tasks.firstWhere((t) => t.id == movedId);
    _tasks.remove(moved);
    // 새 위치 바로 다음 항목 앞에, 맨 끝이면 바로 앞 항목 뒤에 끼워 넣는다
    if (newIndex + 1 < ids.length) {
      _tasks.insert(_tasks.indexWhere((t) => t.id == ids[newIndex + 1]), moved);
    } else {
      final prev = _tasks.indexWhere((t) => t.id == ids[newIndex - 1]);
      _tasks.insert(prev + 1, moved);
    }
    notifyListeners();
  }

  void _edit(String taskId, TaskItem Function(TaskItem) change) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = change(_tasks[index]);
    notifyListeners();
  }
}
