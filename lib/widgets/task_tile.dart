import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/task_item.dart';
import '../theme/app_palette.dart';
import 'round_check.dart';
import 'slidable_actions.dart';

/// 홈 대시보드 할 일 체크리스트 한 줄을 나타내는 카드 (토스 스타일)
/// 좌우로 슬라이드하면 수정/삭제 버튼이 나타난다
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

  String _formatDueDate(DateTime? date) {
    if (date == null) return '마감 없음';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$month/$day $hour:$minute';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Slidable(
      key: ValueKey(task.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.42,
        children: buildEditDeleteActions(onEdit: onEdit, onDelete: onDelete),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          color: palette.card,
          borderRadius: BorderRadius.circular(AppPalette.cardRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onChanged(!task.isDone),
            child: Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            decoration: task.isDone
                                ? TextDecoration.lineThrough
                                : TextDecoration.none,
                            color: task.isDone
                                ? palette.subText
                                : palette.titleText,
                          ),
                          child: Text(task.title),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            if (roomName != null) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: palette.accentChipBackground,
                                  borderRadius: BorderRadius.circular(
                                    AppPalette.chipRadius,
                                  ),
                                ),
                                child: Text(
                                  roomName!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.accent,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              _formatDueDate(task.dueDate),
                              style: TextStyle(
                                fontSize: 12,
                                color: palette.subText,
                              ),
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
        ),
      ),
    );
  }
}
