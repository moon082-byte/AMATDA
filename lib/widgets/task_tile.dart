import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/task_item.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';
import 'common/due_badge.dart';
import 'common/tag_chip.dart';
import 'round_check.dart';
import 'slidable_actions.dart';

/// '오늘 할일' 체크리스트 한 줄 카드. 탭하면 완료 처리되고,
/// 왼쪽으로 슬라이드하면 수정/삭제 버튼이 나타난다.
class TaskTile extends StatelessWidget {
  final TaskItem task;
  final String? roomName;
  final ValueChanged<bool?> onChanged;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TaskTile({
    super.key,
    required this.task,
    required this.roomName,
    required this.onChanged,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: ValueKey(task.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.44,
          children: buildEditDeleteActions(
            context,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ),
        child: AppCard(
          onTap: () => onChanged(!task.isDone),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            children: [
              RoundCheck(isDone: task.isDone),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: DefaultTextStyle.of(context).style.merge(
                        text.title.copyWith(
                          decoration: task.isDone
                              ? TextDecoration.lineThrough
                              : TextDecoration.none,
                          color: task.isDone
                              ? palette.subText
                              : palette.titleText,
                        ),
                      ),
                      child: Text(task.title),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        DueBadge(dueDate: task.dueDate, isDone: task.isDone),
                        if (roomName != null)
                          TagChip.neutral(
                            context,
                            roomName!,
                            icon: Icons.tag_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
