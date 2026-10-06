import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/routine.dart';
import '../models/task_reminder.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';
import 'common/tag_chip.dart';
import 'round_check.dart';
import 'slidable_actions.dart';

/// 루틴 한 줄 카드. 오늘 할 루틴이면 탭해서 완료 체크하고,
/// 왼쪽으로 밀면 수정/삭제 버튼이 나온다.
class RoutineTile extends StatelessWidget {
  final Routine routine;

  /// 완료 여부를 보여줄 날짜 (보통 오늘)
  final DateTime day;

  /// 그날 할 루틴이 아니면 null (체크 대신 반복 아이콘을 보여주고, 탭하면 수정)
  final VoidCallback? onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const RoutineTile({
    super.key,
    required this.routine,
    required this.day,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final checkable = onToggle != null;
    final done = checkable && routine.isDoneOn(day);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: ValueKey(routine.id),
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
          onTap: onToggle ?? onEdit,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            children: [
              if (checkable)
                RoundCheck(isDone: done, color: palette.routine)
              else
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: palette.routineSoft,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.repeat_rounded,
                    size: 15,
                    color: palette.routine,
                  ),
                ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 250),
                      style: DefaultTextStyle.of(context).style.merge(
                            text.title.copyWith(
                              decoration: done
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                              color: done ? palette.subText : palette.titleText,
                            ),
                          ),
                      child: Text(routine.name),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        TagChip.routine(
                          context,
                          '${routine.repeatLabel} ${routine.timeLabel}',
                          icon: Icons.repeat_rounded,
                        ),
                        if (routine.reminders.isNotEmpty)
                          TagChip.neutral(
                            context,
                            remindersSummary(routine.reminders),
                            icon: Icons.notifications_rounded,
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
