import 'package:flutter/material.dart';
import '../models/task_item.dart';
import 'common/due_badge.dart';
import 'common/tag_chip.dart';

/// 할 일 제목 아래 붙는 정보 칩: 마감, 리마인드, 방 이름, 세부 항목·메모 수
class TaskMetaChips extends StatelessWidget {
  final TaskItem task;
  final String? roomName;
  final bool showCounts;

  const TaskMetaChips({
    super.key,
    required this.task,
    this.roomName,
    this.showCounts = false,
  });

  @override
  Widget build(BuildContext context) {
    final doneSubTasks = task.subTasks.where((s) => s.isDone).length;
    final reminder = task.reminder;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        DueBadge(dueDate: task.dueDate, isDone: task.isDone),
        if (reminder != null && task.dueDate != null)
          TagChip.accent(
            context,
            reminder.label,
            icon: Icons.notifications_rounded,
          ),
        if (roomName != null)
          TagChip.neutral(context, roomName!, icon: Icons.tag_rounded),
        if (showCounts && task.subTasks.isNotEmpty)
          TagChip.neutral(
            context,
            '$doneSubTasks/${task.subTasks.length}',
            icon: Icons.checklist_rounded,
          ),
        if (showCounts && task.notes.isNotEmpty)
          TagChip.neutral(
            context,
            '${task.notes.length}',
            icon: Icons.sticky_note_2_outlined,
          ),
      ],
    );
  }
}
