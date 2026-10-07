import '../models/task_item.dart';

/// 마감이 가장 가까운(가장 이른) 미완료 할 일. 이미 지난 마감도 포함한다. 없으면 null.
/// 업무방 카드의 D-Day와 업무방 상세 상단의 마감·알림 표시에 쓴다.
TaskItem? nearestDueTask(Iterable<TaskItem> tasks) {
  TaskItem? nearest;
  for (final t in tasks) {
    if (t.isDone || t.dueDate == null) continue;
    if (nearest == null || t.dueDate!.isBefore(nearest.dueDate!)) nearest = t;
  }
  return nearest;
}
