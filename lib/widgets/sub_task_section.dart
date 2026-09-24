import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sub_task.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'inline_add_field.dart';
import 'round_check.dart';

/// 할 일 상세에서 하위 세부 체크리스트를 보여주고 추가하는 섹션
class SubTaskSection extends StatelessWidget {
  final TaskItem task;

  const SubTaskSection({super.key, required this.task});

  void _addSubTask(BuildContext context, String title) {
    final subTask = SubTask(
      id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
    );
    context.read<RoomProvider>().addSubTask(task.id, subTask);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final provider = context.read<RoomProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('세부 체크리스트', style: text.label.copyWith(fontSize: 13)),
        const SizedBox(height: 6),
        ...task.subTasks.map(
          (sub) => GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => provider.toggleSubTask(task.id, sub.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Row(
                children: [
                  RoundCheck(isDone: sub.isDone, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sub.title,
                      style: text.body.copyWith(
                        fontSize: 14,
                        decoration: sub.isDone
                            ? TextDecoration.lineThrough
                            : TextDecoration.none,
                        decorationColor: palette.subText,
                        color: sub.isDone ? palette.subText : palette.titleText,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        InlineAddField(
          hint: '세부 항목 추가',
          onAdd: (value) => _addSubTask(context, value),
        ),
      ],
    );
  }
}
