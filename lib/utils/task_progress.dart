import '../models/task_item.dart';

/// 할 일 진행률(0~1): 세부 체크리스트 완료 비율. 세부 항목이 없으면 미완료 0, 완료 1.
/// 할 일 자체를 완료하면 세부 항목과 관계없이 1.
double taskProgress(TaskItem task) {
  if (task.isDone) return 1;
  final subs = task.subTasks;
  if (subs.isEmpty) return 0;
  return subs.where((s) => s.isDone).length / subs.length;
}
