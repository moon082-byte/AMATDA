import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/task_actions.dart';
import 'common/app_card.dart';
import 'note_section.dart';
import 'reorder_handle.dart';
import 'round_check.dart';
import 'slidable_actions.dart';
import 'sub_task_section.dart';
import 'task_meta_chips.dart';

/// 업무방 상세 화면의 할 일 카드. 탭하면 아코디언처럼 펼쳐져 하위 체크리스트와
/// 메모를 보여준다. 왼쪽으로 밀면 수정/삭제, 윗부분을 꾹 누르면 순서를 바꿀 수 있다.
class TaskDetailCard extends StatefulWidget {
  final TaskItem task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final int? dragIndex;

  const TaskDetailCard({
    super.key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
    this.dragIndex,
  });

  @override
  State<TaskDetailCard> createState() => _TaskDetailCardState();
}

class _TaskDetailCardState extends State<TaskDetailCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final task =
        context.watch<RoomProvider>().taskById(widget.task.id) ?? widget.task;

    final header = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => setState(() => _expanded = !_expanded),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => toggleTaskWithUndo(context, task),
              child: RoundCheck(isDone: task.isDone),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, style: text.title),
                  const SizedBox(height: 8),
                  TaskMetaChips(task: task, showCounts: true),
                ],
              ),
            ),
            AnimatedRotation(
              turns: _expanded ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more_rounded, color: palette.subText),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        key: ValueKey(task.id),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.44,
          children: buildEditDeleteActions(
            context,
            onEdit: widget.onEdit,
            onDelete: widget.onDelete,
          ),
        ),
        child: AppCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              ReorderHandle(index: widget.dragIndex, child: header),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: !_expanded
                    ? const SizedBox(width: double.infinity)
                    : Padding(
                        padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Divider(height: 1, color: palette.border),
                            const SizedBox(height: 16),
                            SubTaskSection(task: task),
                            const SizedBox(height: 20),
                            NoteSection(task: task),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
