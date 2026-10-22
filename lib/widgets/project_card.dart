import 'package:flutter/material.dart';

import '../models/project.dart';
import '../models/project_room.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';
import 'common/due_badge.dart';
import 'common/progress_bar.dart';

import 'package:flutter_slidable/flutter_slidable.dart';

import 'task_row_actions.dart';
import 'slidable_actions.dart';

/// 프로젝트 한 장: 이름·마감 D-DAY·달성률 막대, 토글로 세부업무(담당자·마감)를 펼친다.
/// 팀장은 카드를 밀어 [수정][삭제], [+ 세부업무]로 추가, 업무 줄을 눌러 수정·✕로 삭제한다.
class ProjectCard extends StatefulWidget {
  final Project project;
  final ProjectRoom room;
  final TaskRowActions actions;
  final VoidCallback onAddTask;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProjectCard({
    super.key,
    required this.project,
    required this.room,
    required this.actions,
    required this.onAddTask,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<ProjectCard> createState() => _ProjectCardState();
}

class _ProjectCardState extends State<ProjectCard> {
  // 내 진행 중 업무가 있거나, 팀장이 검토할 업무가 있으면 처음부터 펼친다
  late bool _open = widget.project.tasks.any(
    (t) =>
        (t.assigneeId == widget.room.myId && !t.isDone) ||
        (widget.room.isLeader && t.status == TaskStatus.review),
  );

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final p = widget.project;
    final room = widget.room;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(p.id),
        enabled: room.isLeader,
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
          padding: const EdgeInsets.fromLTRB(18, 14, 8, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => setState(() => _open = !_open),
                child: Row(
                  children: [
                    Expanded(child: Text(p.name, style: text.title)),
                    if (p.remindAt.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Icon(
                          Icons.notifications_active_rounded,
                          size: 16,
                          color: palette.accent,
                          semanticLabel: '리마인더 ${p.remindAt.length}개',
                        ),
                      ),
                    if (p.dueAt != null)
                      DueBadge(
                        dueDate: p.dueAt,
                        dDay: true,
                        isDone: p.progress == 1,
                      ),
                    Icon(
                      _open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: palette.subText,
                      semanticLabel: _open ? '접기' : '세부업무 펼치기',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Row(
                  children: [
                    Expanded(child: ProgressBar(value: p.progress, height: 6)),
                    const SizedBox(width: 10),
                    Text(
                      '${(p.progress * 100).round()}% · ${p.doneCount}/${p.tasks.length}',
                      style: text.caption,
                    ),
                  ],
                ),
              ),
              if (_open) ...[
                const SizedBox(height: 6),
                for (final t in p.tasks) widget.actions.row(t),
                if (p.tasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text('아직 세부업무가 없어요', style: text.caption),
                  ),
                if (room.isLeader)
                  TextButton.icon(
                    onPressed: widget.onAddTask,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('세부업무 추가'),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
