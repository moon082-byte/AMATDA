import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/project_room.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/due_badge.dart';
import 'reminder_bell_button.dart';

/// 방 화면 어디서나(프로젝트 탭·오늘의 일정·팀원 탭) 같은 업무 줄을 만들기 위한 동작 묶음
class TaskRowActions {
  final ProjectRoom room;
  final void Function(ProjectTask) complete;
  final void Function(ProjectTask) remind;
  final void Function(ProjectTask) edit;
  final void Function(ProjectTask) delete;
  final int Function(ProjectTask) reminderCount;

  const TaskRowActions({
    required this.room,
    required this.complete,
    required this.remind,
    required this.edit,
    required this.delete,
    required this.reminderCount,
  });

  /// [t] 한 줄: 내 진행 중 업무면 [🔔][완료], 팀장이면 눌러 수정. [withProject]면 프로젝트 이름도.
  Widget row(ProjectTask t, {bool withProject = false}) {
    final mineOpen = t.assigneeId == room.myId && !t.isDone && !room.invited;
    return ProjectTaskRow(
      key: ValueKey(t.id),
      task: t,
      assignee: room.memberById(t.assigneeId)?.handle ?? '담당자 없음',
      projectName: withProject ? room.projectOf(t).name : null,
      mine: t.assigneeId == room.myId,
      onComplete: mineOpen ? () => complete(t) : null,
      onReminder: mineOpen ? () => remind(t) : null,
      reminderCount: reminderCount(t),
      onEdit: room.isLeader ? () => edit(t) : null,
      onDelete: room.isLeader ? () => delete(t) : null,
    );
  }
}

/// 세부업무 한 줄: 완료 표시, 업무 이름, 담당자, 마감 D-DAY.
/// 내 진행 중 업무면 [완료] 버튼, 팀장이면 줄을 눌러 수정.
class ProjectTaskRow extends StatelessWidget {
  final ProjectTask task;
  final String assignee;

  /// 여러 프로젝트가 섞인 목록(오늘의 일정)에서 보여줄 프로젝트 이름
  final String? projectName;
  final bool mine;
  final VoidCallback? onComplete;

  /// 내 업무의 🔔 (개인 할일 리마인더)
  final VoidCallback? onReminder;
  final int reminderCount;
  final VoidCallback? onEdit;

  /// 팀장의 ✕ (삭제 전 확인 창)
  final VoidCallback? onDelete;

  const ProjectTaskRow({
    super.key,
    required this.task,
    required this.assignee,
    this.projectName,
    this.mine = false,
    this.onComplete,
    this.onReminder,
    this.reminderCount = 0,
    this.onEdit,
    this.onDelete,
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
                      if (projectName != null) Text('📁 $projectName', style: text.caption),
                      Text(mine ? '나 · $assignee' : assignee,
                          style: text.caption.copyWith(color: mine ? palette.accent : null)),
                      if (!done && task.dueAt != null) DueBadge(dueDate: task.dueAt, dDay: true),
                    ],
                  ),
                ],
              ),
            ),
            if (onReminder != null)
              ReminderBellButton(count: reminderCount, compact: true, onTap: onReminder!),
            if (onDelete != null)
              IconButton(
                onPressed: onDelete,
                tooltip: '업무 삭제',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.close_rounded, size: 18, color: palette.subText),
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
