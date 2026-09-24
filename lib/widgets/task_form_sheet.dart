import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import '../utils/pick_date_time.dart';
import 'common/app_sheet.dart';
import 'due_date_field.dart';
import 'labeled_text_field.dart';

/// 특정 업무방에 새 할 일을 추가하는 바텀시트를 띄운다
Future<void> showAddTaskSheet(BuildContext context, String roomId) {
  return showAppSheet(context, (_) => TaskFormSheet(roomId: roomId));
}

/// 기존 할 일의 제목/마감기한을 수정하는 바텀시트를 띄운다
Future<void> showEditTaskSheet(BuildContext context, TaskItem task) {
  return showAppSheet(context, (_) => TaskFormSheet(task: task));
}

/// 할 일 추가/수정 공용 폼. [task]가 있으면 수정 모드로 동작한다.
class TaskFormSheet extends StatefulWidget {
  final TaskItem? task;
  final String? roomId;

  const TaskFormSheet({super.key, this.task, this.roomId});

  @override
  State<TaskFormSheet> createState() => _TaskFormSheetState();
}

class _TaskFormSheetState extends State<TaskFormSheet> {
  late final _titleController =
      TextEditingController(text: widget.task?.title ?? '');
  late DateTime? _dueDate = widget.task?.dueDate;

  bool get _isEdit => widget.task != null;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await pickDateTime(context, initial: _dueDate);
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final provider = context.read<RoomProvider>();

    final task = widget.task;
    if (task != null) {
      provider.updateTask(task.copyWithEdits(title: title, dueDate: _dueDate));
    } else {
      provider.addTask(TaskItem(
        id: 'task_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        dueDate: _dueDate,
        roomId: widget.roomId,
        createdAt: DateTime.now(),
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _titleController.text.trim().isNotEmpty;

    return SheetScaffold(
      title: _isEdit ? '할 일 수정' : '할 일 추가',
      primaryLabel: _isEdit ? '저장하기' : '추가하기',
      onPrimary: canSubmit ? _submit : null,
      children: [
        LabeledTextField(
          label: '할 일',
          controller: _titleController,
          hint: '예: 주간 보고서 초안 공유',
          autofocus: !_isEdit,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: 20),
        DueDateField(
          label: '마감 기한',
          value: _dueDate,
          placeholder: '마감 기한 선택 (선택)',
          onTap: _pickDueDate,
          onClear: () => setState(() => _dueDate = null),
        ),
      ],
    );
  }
}
