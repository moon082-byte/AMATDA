import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sub_task.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import '../theme/app_typography.dart';
import '../utils/ids.dart';
import '../utils/task_actions.dart';
import 'reminder_popup.dart';
import 'inline_add_field.dart';
import 'reorder_handle.dart';
import 'sub_task_row.dart';

/// 할 일 상세에서 하위 세부 체크리스트를 보여주고 추가·수정·삭제·순서 변경(꾹 눌러 끌기)하는 섹션
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

  /// 상위 할 일의 마감 기준으로 이 세부 항목의 리마인더를 고른다
  Future<void> _editReminders(BuildContext context, SubTask sub) async {
    final due = task.dueDate;
    if (due == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('할 일에 마감 기한을 정하면 세부 항목 리마인더를 설정할 수 있어요'),
      ));
      return;
    }
    final picked = await showReminderPopup(
      context,
      initial: sub.reminders,
      dueDate: due,
      title: '리마인더 · ${sub.title}',
    );
    if (picked == null || !context.mounted) return;
    context.read<RoomProvider>().setSubTaskReminders(task.id, sub.id, picked);
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
        // 꾹 눌러 끌면 순서를 바꾼다
        ReorderableListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: false,
          proxyDecorator: liftedProxy,
          itemCount: task.subTasks.length,
          onReorderItem: (from, to) => provider.reorderSubTasks(task.id, from, to),
          itemBuilder: (context, i) {
            final sub = task.subTasks[i];
            return ReorderHandle(
              key: ValueKey(sub.id),
              index: i,
              child: SubTaskRow(
                subTask: sub,
                onToggle: () => provider.toggleSubTask(task.id, sub.id),
                onRename: (title) => provider.renameSubTask(task.id, sub.id, title),
                onDelete: () => _deleteSubTask(context, sub),
                onReminder: () => _editReminders(context, sub),
                reminderReady: task.dueDate != null,
              ),
            );
          },
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
