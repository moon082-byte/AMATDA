import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/task_progress.dart';
import 'common/progress_bar.dart';

/// 할 일 카드의 진행률 막대와 퍼센트 (세부 체크리스트 완료 비율)
class TaskProgressBar extends StatelessWidget {
  final TaskItem task;

  const TaskProgressBar({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final value = taskProgress(task);
    final color = value >= 1 ? palette.success : palette.accent;

    return Row(
      children: [
        Expanded(child: ProgressBar(value: value, height: 6, color: color)),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text(
            '${(value * 100).round()}%',
            textAlign: TextAlign.right,
            style: context.text.micro.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}
