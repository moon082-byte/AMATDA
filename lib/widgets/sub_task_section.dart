import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sub_task.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import '../theme/app_typography.dart';
import '../utils/ids.dart';
import '../utils/task_actions.dart';
import 'inline_add_field.dart';
import 'sub_task_row.dart';

/// 할 일 상세에서 하위 세부 체크리스트를 보여주고 추가·수정·삭제하는 섹션
class SubTaskSection extends StatelessWidget {
  final TaskItem task;

  const SubTaskSection({super.key, required this.task});

  void _addSubTask(BuildContext context, String title) {
    final subTask = SubTask(
      id: newId('sub'),
      title: title,
    );
    context.read<RoomProvider>().addSubTask(task.id, subTask);
  }

  void _deleteSubTask(BuildContext context, SubTask sub) {
    final provider = context.read<RoomProvider>();
    final index = provider.deleteSubTask(task.id, sub.id);
    if (index == -1) return;
    showUndoSnackBar(
      context,
      '"${sub.title}" 항목을 삭제했어요',
      () => provider.insertSubTask(task.id, sub, index),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final provider = context.read<RoomProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('세부 체크리스트', style: text.label.copyWith(fontSize: 13)),
        const SizedBox(height: 2),
        for (final sub in task.subTasks)
          SubTaskRow(
            key: ValueKey(sub.id),
            subTask: sub,
            onToggle: () => provider.toggleSubTask(task.id, sub.id),
            onRename: (title) => provider.renameSubTask(task.id, sub.id, title),
            onDelete: () => _deleteSubTask(context, sub),
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
