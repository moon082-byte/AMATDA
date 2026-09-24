import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import 'note_section.dart';
import 'round_check.dart';
import 'slidable_actions.dart';
import 'sub_task_section.dart';

/// 업무방 상세 화면의 할 일 카드. 탭하면 아코디언처럼 펼쳐져
/// 하위 체크리스트와 메모를 보여준다. 좌우로 슬라이드하면 수정/삭제 버튼이 나타난다.
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

  String _formatDueDate(DateTime? date) {
    if (date == null) return '마감 없음';
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$m/$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final task =
        context.watch<RoomProvider>().taskById(widget.task.id) ?? widget.task;
    final doneSubTasks = task.subTasks.where((s) => s.isDone).length;
    final metaText = task.subTasks.isEmpty
        ? _formatDueDate(task.dueDate)
        : '세부 $doneSubTasks/${task.subTasks.length} · ${_formatDueDate(task.dueDate)}';

    return Slidable(
      key: ValueKey(task.id),
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.42,
        children: buildEditDeleteActions(
          onEdit: widget.onEdit,
          onDelete: widget.onDelete,
        ),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(AppPalette.cardRadius),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            InkWell(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                          Text(
                            task.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: palette.titleText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            metaText,
                            style: TextStyle(
                              fontSize: 12,
                              color: palette.subText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: palette.subText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity, height: 0),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SubTaskSection(task: task),
                    const SizedBox(height: 16),
                    NoteSection(task: task),
                  ],
                ),
              ),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 220),
              sizeCurve: Curves.easeInOut,
            ),
          ],
        ),
      ),
    );
  }
}
