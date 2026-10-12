import 'task_reminder.dart';

/// 할 일 하위의 단계별 세부 체크리스트 항목.
/// [reminders]는 상위 할 일의 마감 기한 기준으로 울린다.
class SubTask {
  final String id;
  final String title;
  final bool isDone;
  final List<TaskReminder> reminders;

  const SubTask({
    required this.id,
    required this.title,
    this.isDone = false,
    this.reminders = const [],
  });

  SubTask copyWith({String? title, bool? isDone, List<TaskReminder>? reminders}) {
    return SubTask(
      id: id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      reminders: reminders ?? this.reminders,
    );
  }
}
