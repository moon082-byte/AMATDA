import 'package:flutter/material.dart';
import '../models/project.dart';
import '../utils/date_format.dart';
import '../utils/pick_date_time.dart';
import '../widgets/field_label.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/schedule_button.dart';
import '../widgets/sheet_drag_handle.dart';

/// 팀장이 프로젝트·세부업무를 추가·수정하는 아래 시트들.
/// 저장하면 입력값을, [삭제]를 누르면 delete: true를, 닫으면 null을 돌려준다.
typedef TaskInput = ({String title, String? assigneeId, DateTime? due, bool delete});
typedef ProjectInput = ({String name, DateTime? due, bool delete});

Future<T?> _sheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(child: child),
      ),
    );

Future<ProjectInput?> showProjectSheet(BuildContext context, {Project? project}) =>
    _sheet(context, _EditSheet(
      title: project == null ? '프로젝트 추가' : '프로젝트 수정',
      label: '프로젝트 이름',
      initialName: project?.name ?? '',
      initialDue: project?.dueAt,
      canDelete: project != null,
      build: (name, _, due, delete) => (name: name, due: due, delete: delete),
    ));

Future<TaskInput?> showTaskSheet(BuildContext context,
        {ProjectTask? task, required List<ProjectMember> members}) =>
    _sheet(context, _EditSheet(
      title: task == null ? '세부업무 추가' : '세부업무 수정',
      label: '업무 이름',
      initialName: task?.title ?? '',
      initialDue: task?.dueAt,
      members: members,
      initialAssignee: task?.assigneeId,
      canDelete: task != null,
      build: (name, assignee, due, delete) =>
          (title: name, assigneeId: assignee, due: due, delete: delete),
    ));

class _EditSheet<T> extends StatefulWidget {
  final String title;
  final String label;
  final String initialName;
  final DateTime? initialDue;
  final List<ProjectMember>? members;
  final String? initialAssignee;
  final bool canDelete;
  final T Function(String name, String? assignee, DateTime? due, bool delete) build;

  const _EditSheet({
    required this.title,
    required this.label,
    required this.initialName,
    required this.initialDue,
    required this.canDelete,
    required this.build,
    this.members,
    this.initialAssignee,
  });

  @override
  State<_EditSheet<T>> createState() => _EditSheetState<T>();
}

class _EditSheetState<T> extends State<_EditSheet<T>> {
  late final _name = TextEditingController(text: widget.initialName);
  late DateTime? _due = widget.initialDue;
  late String? _assignee = widget.initialAssignee;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _done({bool delete = false}) {
    if (!delete && _name.text.trim().isEmpty) return;
    Navigator.pop(context, widget.build(_name.text.trim(), _assignee, _due, delete));
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
