import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../models/task_reminder.dart';
import '../providers/room_provider.dart';
import '../utils/ids.dart';
import '../utils/pick_date_time.dart';
import '../widgets/common/app_page.dart';
import '../widgets/due_date_field.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/reminder_list_editor.dart';
import '../widgets/room_picker.dart';

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
  late List<TaskReminder> _reminders = widget.task?.reminders ?? const [];
  late String? _roomId = widget.roomId;

  /// 업무방 밖(오늘 할일 화면)에서 새로 추가할 때만 업무방을 고른다
  bool get _pickRoom => widget.task == null && widget.roomId == null;

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
    final reminders = _dueDate == null ? <TaskReminder>[] : _reminders;
    final provider = context.read<RoomProvider>();

    final task = widget.task;
    if (task != null) {
      provider.updateTask(task.copyWithEdits(
        title: title,
        dueDate: _dueDate,
        reminders: reminders,
      ));
    } else {
      provider.addTask(TaskItem(
        id: newId('task'),
        title: title,
        dueDate: _dueDate,
        reminders: reminders,
        roomId: _roomId,
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
          if (_pickRoom) ...[
            const SizedBox(height: 24),
            RoomPicker(
              value: _roomId,
              onChanged: (id) => setState(() => _roomId = id),
            ),
          ],
          const SizedBox(height: 24),
          DueDateField(
            label: '마감 기한',
            value: _dueDate,
            placeholder: '마감 기한 선택 (선택)',
            onTap: _pickDueDate,
            onClear: () => setState(() => _dueDate = null),
          ),
          const SizedBox(height: 24),
          ReminderListEditor(
            label: '리마인드 알림',
            dueDate: _dueDate,
            value: _reminders,
            onChanged: (r) => setState(() => _reminders = r),
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
