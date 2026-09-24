import 'package:flutter/foundation.dart';
import '../models/note.dart';
import '../models/sub_task.dart';
import '../models/task_item.dart';
import '../models/telegram_room.dart';

/// 업무방, 할 일, 하위 체크리스트, 메모 상태를 관리
class RoomProvider extends ChangeNotifier {
  final List<TelegramRoom> _rooms = List.of(mockTelegramRooms);
  final List<TaskItem> _tasks = List.of(mockTaskItems);

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

  TelegramRoom? roomById(String id) {
    for (final room in _rooms) {
      if (room.id == id) return room;
    }
    return null;
  }

  TaskItem? taskById(String id) {
    for (final task in _tasks) {
      if (task.id == id) return task;
    }
    return null;
  }

  List<TaskItem> tasksForRoom(String roomId) =>
      _tasks.where((t) => t.roomId == roomId).toList();

  /// 방에 속한, 아직 완료되지 않은 할 일만
  List<TaskItem> activeTasksForRoom(String roomId) =>
      _tasks.where((t) => t.roomId == roomId && !t.isDone).toList();

  int pendingCountForRoom(String roomId) =>
      _tasks.where((t) => t.roomId == roomId && !t.isDone).length;

  void addRoom(TelegramRoom room) {
    _rooms.add(room);
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

  void updateTask(TaskItem updated) {
    final index = _tasks.indexWhere((t) => t.id == updated.id);
    if (index == -1) return;
    _tasks[index] = updated;
    notifyListeners();
  }

  void deleteTask(String taskId) {
    _tasks.removeWhere((t) => t.id == taskId);
    notifyListeners();
  }

  void toggleTask(String taskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    _tasks[index] = _tasks[index].markDone(!_tasks[index].isDone);
    notifyListeners();
  }

  void addSubTask(String taskId, SubTask subTask) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final updated = List.of(_tasks[index].subTasks)..add(subTask);
    _tasks[index] = _tasks[index].copyWith(subTasks: updated);
    notifyListeners();
  }

  void toggleSubTask(String taskId, String subTaskId) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final updated = _tasks[index].subTasks.map((s) {
      return s.id == subTaskId ? s.copyWith(isDone: !s.isDone) : s;
    }).toList();
    _tasks[index] = _tasks[index].copyWith(subTasks: updated);
    notifyListeners();
  }

  void addNote(String taskId, Note note) {
    final index = _tasks.indexWhere((t) => t.id == taskId);
    if (index == -1) return;
    final updated = List.of(_tasks[index].notes)..add(note);
    _tasks[index] = _tasks[index].copyWith(notes: updated);
    notifyListeners();
  }
}
