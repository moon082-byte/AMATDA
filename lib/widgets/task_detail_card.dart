import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';
import 'common/due_badge.dart';
import 'common/tag_chip.dart';
import 'note_section.dart';
import 'round_check.dart';
import 'slidable_actions.dart';
import 'sub_task_section.dart';

/// 업무방 상세 화면의 할 일 카드. 탭하면 아코디언처럼 펼쳐져
/// 하위 체크리스트와 메모를 보여준다. 왼쪽으로 슬라이드하면 수정/삭제 버튼이 나타난다.
class TaskDetailCard extends StatefulWidget {
  final TaskItem task;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const TaskDetailCard({
    super.key,
    required this.task,
    required this.onEdit,
    required this.onDelete,
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
    final doneSubTasks = task.subTasks.where((s) => s.isDone).length;

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
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 12, 16),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () =>
                            context.read<RoomProvider>().toggleTask(task.id),
                        child: RoundCheck(isDone: task.isDone),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(task.title, style: text.title),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                DueBadge(dueDate: task.dueDate),
                                if (task.subTasks.isNotEmpty)
                                  TagChip.neutral(
                                    context,
                                    '$doneSubTasks/${task.subTasks.length}',
                                    icon: Icons.checklist_rounded,
                                  ),
                                if (task.notes.isNotEmpty)
                                  TagChip.neutral(
                                    context,
                                    '${task.notes.length}',
                                    icon: Icons.sticky_note_2_outlined,
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0,
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          Icons.expand_more_rounded,
                          color: palette.subText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
