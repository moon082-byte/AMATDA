import 'package:flutter/material.dart';
import '../models/project.dart';
import '../utils/date_format.dart';
import '../utils/pick_date_time.dart';
import 'field_label.dart';
import 'labeled_text_field.dart';
import 'remind_at_popup.dart';
import 'reminder_bell_button.dart';
import 'schedule_button.dart';
import 'sheet_drag_handle.dart';

/// 팀장의 프로젝트·세부업무 입력 시트 내용: 이름, (세부업무) 담당자, 마감, (프로젝트) 리마인더, 저장·삭제.
/// 결과 모양은 [build]가 정한다 (views/project_sheets.dart).
class ProjectEditSheet<T> extends StatefulWidget {
  final String title;
  final String label;
  final String initialName;
  final DateTime? initialDue;
  final List<ProjectMember>? members;
  final String? initialAssignee;

  /// 있으면 🔔 리마인더 칸을 보여준다 (프로젝트)
  final List<DateTime>? initialRemindAt;
  final bool canDelete;
  final T Function(String name, String? assignee, DateTime? due, List<DateTime> remindAt, bool delete) build;

  const ProjectEditSheet({
    super.key,
    required this.title,
    required this.label,
    required this.initialName,
    required this.initialDue,
    required this.canDelete,
    required this.build,
    this.members,
    this.initialAssignee,
    this.initialRemindAt,
  });

  @override
  State<ProjectEditSheet<T>> createState() => ProjectEditSheetState<T>();
}

class ProjectEditSheetState<T> extends State<ProjectEditSheet<T>> {
  late final _name = TextEditingController(text: widget.initialName);
  late DateTime? _due = widget.initialDue;
  late String? _assignee = widget.initialAssignee;
  late List<DateTime> _remindAt = widget.initialRemindAt ?? const [];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done({bool delete = false}) {
    if (!delete && _name.text.trim().isEmpty) return;
    Navigator.pop(context, widget.build(_name.text.trim(), _assignee, _due, _remindAt, delete));
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.members;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        const SheetDragHandle(),
        const SizedBox(height: 16),
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        LabeledTextField(label: widget.label, controller: _name, hint: '', autofocus: widget.initialName.isEmpty),
        if (members != null) ...[
          const SizedBox(height: 20),
          const FieldLabel('담당자'),
          DropdownButtonFormField<String?>(
            initialValue: members.any((m) => m.userId == _assignee) ? _assignee : null,
            items: [
              const DropdownMenuItem(value: null, child: Text('담당자 없음')),
              for (final m in members) DropdownMenuItem(value: m.userId, child: Text(m.handle)),
            ],
            onChanged: (v) => setState(() => _assignee = v),
          ),
        ],
        const SizedBox(height: 20),
        const FieldLabel('마감기한'),
        Align(
          alignment: Alignment.centerLeft,
          child: ScheduleButton(
            label: _due == null ? null : formatRelativeDateTime(_due!),
            tooltip: '마감기한 선택',
            onTap: () async {
              final picked = await pickDateTime(context, initial: _due);
              if (picked != null) setState(() => _due = picked);
            },
            onClear: () => setState(() => _due = null),
          ),
        ),
        if (widget.initialRemindAt != null) ...[
          const SizedBox(height: 20),
          const FieldLabel('리마인더 (팀장과 진행 중 업무 담당자에게)'),
          Align(
            alignment: Alignment.centerLeft,
            child: ReminderBellButton(
              count: _remindAt.length,
              onTap: () async {
                final picked = await showRemindAtPopup(context,
                    initial: _remindAt, dueDate: _due, title: '프로젝트 리마인더');
                if (picked != null) setState(() => _remindAt = picked);
              },
            ),
          ),
        ],
        const SizedBox(height: 24),
        FilledButton(onPressed: () => _done(), child: const Text('저장하기')),
        if (widget.canDelete)
          TextButton(
            onPressed: () => _done(delete: true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('삭제'),
          ),
      ],
    );
  }
}
