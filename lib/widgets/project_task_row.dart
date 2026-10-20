import 'package:flutter/material.dart';
import '../models/project.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/due_badge.dart';

/// 세부업무 한 줄: 완료 표시, 업무 이름, 담당자, 마감 D-DAY.
/// 내 진행 중 업무면 [완료] 버튼, 팀장이면 줄을 눌러 수정.
class ProjectTaskRow extends StatelessWidget {
  final ProjectTask task;
  final String assignee;
  final bool mine;
  final VoidCallback? onComplete;
  final VoidCallback? onEdit;

  const ProjectTaskRow({
    super.key,
    required this.task,
    required this.assignee,
    this.mine = false,
    this.onComplete,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final done = task.isDone;

    return InkWell(
      onTap: onEdit,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Icon(
              done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
              size: 20,
              color: done ? palette.success : palette.checkboxIdle,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: text.body.copyWith(
                      color: done ? palette.subText : palette.titleText,
                      decoration: done ? TextDecoration.lineThrough : null,
                      fontWeight: mine && !done ? FontWeight.w700 : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(mine ? '나 · $assignee' : assignee,
                          style: text.caption.copyWith(color: mine ? palette.accent : null)),
                      if (!done && task.dueAt != null) DueBadge(dueDate: task.dueAt, dDay: true),
                    ],
                  ),
                ],
              ),
            ),
            if (onComplete != null)
              FilledButton(
                onPressed: onComplete,
                style: FilledButton.styleFrom(
                  minimumSize: const Size(56, 34),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                ),
                child: const Text('완료', style: TextStyle(fontSize: 13)),
              ),
          ],
        ),
      ),
    );
  }
}
