import 'package:flutter/material.dart';
import '../models/project.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/due_badge.dart';
import 'project_status_button.dart';
import 'reminder_bell_button.dart';

/// 세부업무 한 줄: 업무 이름(최종완료면 취소선), 담당자·마감 D-DAY, 오른쪽에 [🔔][✕][상태 버튼].
/// [onRename]이 있으면(팀장) 이름을 눌러 그 자리에서 고친다. [compact]면 이름과 버튼만.
class ProjectTaskRow extends StatefulWidget {
  final ProjectTask task;
  final String assignee;

  /// 여러 프로젝트가 섞인 목록에서 보여줄 프로젝트 이름
  final String? projectName;
  final bool mine;
  final bool compact;

  /// 상태 버튼: [완료]·[검토중]·[검토] (없으면 null)
  final String? statusLabel;
  final bool statusFilled;
  final VoidCallback? onStatus;

  /// 내 업무의 🔔 (개인 할일 리마인더)
  final VoidCallback? onReminder;
  final int reminderCount;
  final ValueChanged<String>? onRename;

  /// 팀장의 ✕ (삭제 전 확인 창)
  final VoidCallback? onDelete;

  const ProjectTaskRow({
    super.key,
    required this.task,
    required this.assignee,
    this.projectName,
    this.mine = false,
    this.compact = false,
    this.statusLabel,
    this.statusFilled = true,
    this.onStatus,
    this.onReminder,
    this.reminderCount = 0,
    this.onRename,
    this.onDelete,
  });

  @override
  State<ProjectTaskRow> createState() => _ProjectTaskRowState();
}

class _ProjectTaskRowState extends State<ProjectTaskRow> {
  final _controller = TextEditingController();
  bool _editing = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEdit() {
    _controller.text = widget.task.title;
    setState(() => _editing = true);
  }

  void _finish() {
    if (!_editing) return;
    final value = _controller.text.trim();
    setState(() => _editing = false);
    if (value.isNotEmpty && value != widget.task.title) widget.onRename?.call(value);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final t = widget.task;
    final done = t.isDone;
    final style = text.body.copyWith(
      color: done ? palette.subText : palette.titleText,
      decoration: done ? TextDecoration.lineThrough : null,
      fontWeight: widget.mine && !done ? FontWeight.w700 : null,
    );
    final title = _editing
        ? TextField(
            controller: _controller,
            autofocus: true,
            style: style,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _finish(),
            onTapOutside: (_) => _finish(),
            decoration: const InputDecoration(
                isDense: true, contentPadding: EdgeInsets.all(8)),
          )
        : GestureDetector(
            onTap: widget.onRename == null ? null : _startEdit,
            behavior: HitTestBehavior.opaque,
            child: Text(t.title, style: style),
          );

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                title,
                if (!widget.compact) ...[
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (widget.projectName != null)
                        Text('📁 ${widget.projectName}', style: text.caption),
                      Text(widget.mine ? '나 · ${widget.assignee}' : widget.assignee,
                          style: text.caption
                              .copyWith(color: widget.mine ? palette.accent : null)),
                      if (done)
                        Text('완료', style: text.caption.copyWith(color: palette.success)),
                      if (!done && t.dueAt != null) DueBadge(dueDate: t.dueAt, dDay: true),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (widget.onReminder != null)
            ReminderBellButton(
                count: widget.reminderCount, compact: true, onTap: widget.onReminder!),
          if (widget.onDelete != null)
            IconButton(
              onPressed: widget.onDelete,
              tooltip: '업무 삭제',
              visualDensity: VisualDensity.compact,
              icon: Icon(Icons.close_rounded, size: 18, color: palette.subText),
            ),
          if (widget.statusLabel case final label?)
            ProjectStatusButton(label, filled: widget.statusFilled, onTap: widget.onStatus),
        ],
      ),
    );
  }
}
