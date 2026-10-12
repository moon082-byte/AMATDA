import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../models/task_reminder.dart';
import '../providers/room_provider.dart';
import '../utils/date_format.dart';
import '../utils/ids.dart';
import '../utils/pick_date_time.dart';
import '../widgets/composer_frame.dart';
import '../widgets/reminder_bell_button.dart';
import '../widgets/reminder_popup.dart';
import '../widgets/room_picker.dart';
import '../widgets/schedule_button.dart';

/// 할 일 추가/수정 입력 블록: [할 일 이름][📅 마감 일시][🔔 리마인더].
/// [task]가 있으면 수정 모드로 동작한다.
class TaskComposer extends StatefulWidget {
  final TaskItem? task;
  final String? roomId;

  const TaskComposer({super.key, this.task, this.roomId});

  @override
  State<TaskComposer> createState() => _TaskComposerState();
}

class _TaskComposerState extends State<TaskComposer> {
  late final _title = TextEditingController(text: widget.task?.title ?? '');
  late DateTime? _due = widget.task?.dueDate;
  late List<TaskReminder> _reminders = widget.task?.reminders ?? const [];
  late String? _roomId = widget.roomId;

  /// 마감 없이 🔔을 눌렀을 때 안내를 보여준다
  bool _askDue = false;

  /// 업무방 밖(오늘 할일 화면)에서 새로 추가할 때만 업무방을 고른다
  bool get _pickRoom => widget.task == null && widget.roomId == null;
  bool get _isEdit => widget.task != null;
  bool get _canSubmit => _title.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickDue() async {
    final picked = await pickDateTime(context, initial: _due);
    if (picked != null && mounted) setState(() => _due = picked);
  }

  Future<void> _editReminders() async {
    final due = _due;
    if (due == null) {
      setState(() => _askDue = true);
      return;
    }
    final picked = await showReminderPopup(
      context,
      initial: _reminders,
      dueDate: due,
    );
    if (picked != null && mounted) setState(() => _reminders = picked);
  }

  void _submit() {
    if (!_canSubmit) return;
    final title = _title.text.trim();
    final reminders = _due == null ? <TaskReminder>[] : _reminders;
    final provider = context.read<RoomProvider>();

    final task = widget.task;
    if (task != null) {
      provider.updateTask(task.copyWithEdits(
        title: title,
        dueDate: _due,
        reminders: reminders,
      ));
    } else {
      provider.addTask(TaskItem(
        id: newId('task'),
        title: title,
        dueDate: _due,
        reminders: reminders,
        roomId: _roomId,
        createdAt: DateTime.now(),
      ));
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final due = _due;
    return ComposerFrame(
      title: _isEdit ? '할 일 수정' : '할 일 추가',
      controller: _title,
      hint: '업무 이름',
      autofocus: !_isEdit,
      schedule: ScheduleButton(
        label: due == null ? null : formatRelativeDateTime(due),
        tooltip: '마감 일시 선택',
        onTap: _pickDue,
        onClear: () => setState(() => _due = null),
      ),
      bell: ReminderBellButton(
        count: due == null ? 0 : _reminders.length,
        ready: due != null,
        onTap: _editReminders,
      ),
      notice: _askDue && due == null
          ? '📅 마감 일시를 먼저 정하면 리마인더를 설정할 수 있어요'
          : null,
      extra: [
        if (_pickRoom)
          RoomPicker(
            value: _roomId,
            onChanged: (id) => setState(() => _roomId = id),
          ),
      ],
      submitLabel: _isEdit ? '저장하기' : '추가하기',
      onSubmit: _canSubmit ? _submit : null,
    );
  }
}
