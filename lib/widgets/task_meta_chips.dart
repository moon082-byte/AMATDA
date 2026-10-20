import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../models/task_reminder.dart';
import 'common/due_badge.dart';
import 'common/tag_chip.dart';
import '../theme/app_palette.dart';

/// 할 일 제목 아래 붙는 정보 칩: 마감, 리마인드, 방 이름, 메모 수 (세부 항목은 진행률 막대로 보여준다)
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
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        if (task.project case final p?)
          TagChip.routine(context, p.label, icon: Icons.folder_rounded),
        DueBadge(dueDate: task.dueDate, isDone: task.isDone),
        // 프로젝트 업무의 마감은 팀장만 바꿀 수 있다
        if (task.isProjectTask)
          Icon(Icons.lock_rounded, size: 14, color: context.palette.subText, semanticLabel: '마감 잠금'),
        if (task.remindAt.isNotEmpty)
          TagChip.accent(
            context,
            remindAtSummary(task.remindAt),
            icon: Icons.notifications_rounded,
          ),
        if (roomName != null)
          TagChip.neutral(context, roomName!, icon: Icons.tag_rounded),
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
