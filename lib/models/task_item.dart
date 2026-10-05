import 'note.dart';
import 'sub_task.dart';

/// 할 일의 우선순위
enum TaskPriority { low, medium, high }

/// 할 일 체크리스트 항목을 나타내는 모델
class TaskItem {
  final String id;
  final String title;
  final String? description;
  final bool isDone;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final TaskPriority priority;
  final String? roomId;
  final DateTime createdAt;
  final List<SubTask> subTasks;
  final List<Note> notes;

  const TaskItem({
    required this.id,
    required this.title,
    this.description,
    this.isDone = false,
    this.dueDate,
    this.completedAt,
    this.priority = TaskPriority.medium,
    this.roomId,
    required this.createdAt,
    this.subTasks = const [],
    this.notes = const [],
  });

  /// 하위 체크리스트/메모만 바꿔 새 인스턴스를 만든다
  TaskItem copyWith({
    List<SubTask>? subTasks,
    List<Note>? notes,
  }) {
    return TaskItem(
      id: id,
      title: title,
      description: description,
      isDone: isDone,
      dueDate: dueDate,
      completedAt: completedAt,
      priority: priority,
      roomId: roomId,
      createdAt: createdAt,
      subTasks: subTasks ?? this.subTasks,
      notes: notes ?? this.notes,
    );
  }

  /// 완료/미완료 토글 시 완료 시각까지 함께 갱신한다
  TaskItem markDone(bool done) {
    return TaskItem(
      id: id,
      title: title,
      description: description,
      isDone: done,
      dueDate: dueDate,
      completedAt: done ? DateTime.now() : null,
      priority: priority,
      roomId: roomId,
      createdAt: createdAt,
      subTasks: subTasks,
      notes: notes,
    );
  }

  /// 제목/마감기한 수정 시 사용한다
  TaskItem copyWithEdits({required String title, DateTime? dueDate}) {
    return TaskItem(
      id: id,
      title: title,
      description: description,
      isDone: isDone,
      dueDate: dueDate,
      completedAt: completedAt,
      priority: priority,
      roomId: roomId,
      createdAt: createdAt,
      subTasks: subTasks,
      notes: notes,
    );
  }
}
