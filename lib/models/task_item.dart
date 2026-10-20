import 'note.dart';
import 'project_link.dart';
import 'sub_task.dart';

/// 할 일의 우선순위
enum TaskPriority { low, medium, high }

/// 할 일 체크리스트 항목을 나타내는 모델.
/// 목록에서의 순서는 저장소에 담긴 순서를 그대로 따른다(드래그로 변경).
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

  /// 리마인더 알림 시각들 (직접 고른 날짜·시간, 마감과 무관하게 울린다)
  final List<DateTime> remindAt;

  /// 프로젝트에서 배정된 업무면 그 연결 (제목·마감 잠금, 체크하면 완료 보고)
  final ProjectLink? project;

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
    this.remindAt = const [],
    this.project,
  });

  bool get isProjectTask => project != null;

  TaskItem _copy({
    String? title,
    bool? isDone,
    DateTime? Function()? dueDate,
    DateTime? Function()? completedAt,
    List<SubTask>? subTasks,
    List<Note>? notes,
    List<DateTime>? remindAt,
    String? Function()? roomId,
  }) {
    return TaskItem(
      id: id,
      title: title ?? this.title,
      description: description,
      isDone: isDone ?? this.isDone,
      dueDate: dueDate != null ? dueDate() : this.dueDate,
      completedAt: completedAt != null ? completedAt() : this.completedAt,
      priority: priority,
      roomId: roomId != null ? roomId() : this.roomId,
      createdAt: createdAt,
      subTasks: subTasks ?? this.subTasks,
      notes: notes ?? this.notes,
      remindAt: remindAt ?? this.remindAt,
      project: project,
    );
  }

  /// 하위 체크리스트/메모만 바꿔 새 인스턴스를 만든다
  TaskItem copyWith({List<SubTask>? subTasks, List<Note>? notes}) =>
      _copy(subTasks: subTasks, notes: notes);

  /// 완료/미완료 토글 시 완료 시각까지 함께 갱신한다
  TaskItem markDone(bool done) => _copy(
        isDone: done,
        completedAt: () => done ? DateTime.now() : null,
      );

  /// 제목/마감기한/리마인드 수정 시 사용한다 (마감이 null이면 해제)
  TaskItem copyWithEdits({
    required String title,
    DateTime? dueDate,
    List<DateTime> remindAt = const [],
  }) =>
      _copy(title: title, dueDate: () => dueDate, remindAt: remindAt);

  /// 업무방 태그만 바꾼다 (프로젝트 업무도 바꿀 수 있다)
  TaskItem withRoom(String? roomId) => _copy(roomId: () => roomId);
}
