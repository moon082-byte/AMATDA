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

/// 화면 UI 개발용 가짜(Mock) 할 일 데이터
final List<TaskItem> mockTaskItems = [
  TaskItem(
    id: 'task_001',
    title: '주간 보고서 작성',
    description: '팀장님께 전달할 주간 업무 보고서 작성',
    dueDate: DateTime(2026, 9, 22),
    priority: TaskPriority.high,
    roomId: 'room_001',
    createdAt: DateTime(2026, 9, 20, 10, 0),
    subTasks: const [
      SubTask(id: 'sub_001', title: '지난주 데이터 정리', isDone: true),
      SubTask(id: 'sub_002', title: '보고서 초안 작성'),
      SubTask(id: 'sub_003', title: '팀장 검토 요청'),
    ],
    notes: [
      Note(
        id: 'note_001',
        content: '금요일 오전까지 초안 공유하기',
        createdAt: DateTime(2026, 9, 20, 11, 0),
      ),
    ],
  ),
  TaskItem(
    id: 'task_002',
    title: '디자인 시안 확인',
    isDone: true,
    dueDate: DateTime(2026, 9, 19),
    completedAt: DateTime(2026, 9, 19, 14, 0),
    roomId: 'room_001',
    createdAt: DateTime(2026, 9, 18, 13, 0),
  ),
  TaskItem(
    id: 'task_003',
    title: '회의실 예약하기',
    description: '다음 주 화요일 오후 팀 회의용',
    dueDate: DateTime(2026, 9, 23),
    priority: TaskPriority.low,
    createdAt: DateTime(2026, 9, 20, 11, 30),
  ),
];
