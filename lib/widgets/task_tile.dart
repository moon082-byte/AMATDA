import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/task_item.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';
import 'reorder_handle.dart';
import 'round_check.dart';
import 'slidable_actions.dart';
import 'task_meta_chips.dart';

/// '오늘 할일' 체크리스트 한 줄 카드. 탭하면 완료 처리되고,
/// 왼쪽으로 밀면 수정/삭제 버튼이, 꾹 누르면 드래그로 순서를 바꿀 수 있다.
class TaskTile extends StatelessWidget {
  final TaskItem task;
  final String? roomName;
  final VoidCallback onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  /// 드래그 정렬 목록 안에서의 위치 (null이면 드래그 불가)
  final int? dragIndex;

  const TaskTile({
    super.key,
    required this.task,
    required this.roomName,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
    this.dragIndex,
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
        child: ReorderHandle(
          index: dragIndex,
          child: AppCard(
            onTap: onToggle,
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
                      TaskMetaChips(task: task, roomName: roomName),
                    ],
                  ),
                ),
                if (dragIndex != null) const DragGrip(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
