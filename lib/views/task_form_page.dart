import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../models/task_reminder.dart';
import '../providers/room_provider.dart';
import '../utils/pick_date_time.dart';
import '../widgets/common/app_page.dart';
import '../widgets/due_date_field.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/reminder_picker.dart';

/// 할 일 추가/수정 공용 입력 화면. [task]가 있으면 수정 모드로 동작한다.
/// 입력칸을 화면 위쪽에 두어 모바일 키보드에 가리지 않게 한다.
class TaskFormPage extends StatefulWidget {
  final TaskItem? task;
  final String? roomId;

  const TaskFormPage({super.key, this.task, this.roomId});

  @override
  State<TaskFormPage> createState() => _TaskFormPageState();
}

class _TaskFormPageState extends State<TaskFormPage> {
  late final _titleController =
      TextEditingController(text: widget.task?.title ?? '');
  late DateTime? _dueDate = widget.task?.dueDate;
  late TaskReminder? _reminder = widget.task?.reminder;

  bool get _isEdit => widget.task != null;
  bool get _canSubmit => _titleController.text.trim().isNotEmpty;

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
    if (!_canSubmit) return;
    final title = _titleController.text.trim();
    final reminder = _dueDate == null ? null : _reminder;
    final provider = context.read<RoomProvider>();

    final task = widget.task;
    if (task != null) {
      provider.updateTask(task.copyWithEdits(
        title: title,
        dueDate: _dueDate,
        reminder: reminder,
      ));
    } else {
      provider.addTask(TaskItem(
        id: 'task_${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        dueDate: _dueDate,
        reminder: reminder,
        roomId: widget.roomId,
        createdAt: DateTime.now(),
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: _isEdit ? '할 일 수정' : '할 일 추가',
      closeIcon: true,
      actions: [saveAction(_canSubmit ? _submit : null)],
      slivers: [
        paddedSliver(top: 8, [
          LabeledTextField(
            label: '할 일',
            controller: _titleController,
            hint: '예: 주간 보고서 초안 공유',
            autofocus: !_isEdit,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          DueDateField(
            label: '마감 기한',
            value: _dueDate,
            placeholder: '마감 기한 선택 (선택)',
            onTap: _pickDueDate,
            onClear: () => setState(() => _dueDate = null),
          ),
          const SizedBox(height: 24),
          ReminderPicker(
            dueDate: _dueDate,
            value: _reminder,
            onChanged: (r) => setState(() => _reminder = r),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: Text(_isEdit ? '저장하기' : '추가하기'),
          ),
        ]),
      ],
    );
  }
}
