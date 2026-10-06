import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/routine.dart';
import '../models/task_reminder.dart';
import '../providers/routine_provider.dart';
import '../utils/date_format.dart';
import '../utils/ids.dart';
import '../widgets/common/app_page.dart';
import '../widgets/due_date_field.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/reminder_list_editor.dart';
import '../widgets/reminder_unit_selector.dart';
import '../widgets/routine_repeat_field.dart';

/// 루틴 추가/수정 공용 입력 화면. [routine]이 있으면 수정 모드로 동작한다.
class RoutineFormPage extends StatefulWidget {
  final Routine? routine;

  const RoutineFormPage({super.key, this.routine});

  @override
  State<RoutineFormPage> createState() => _RoutineFormPageState();
}

class _RoutineFormPageState extends State<RoutineFormPage> {
  late final _nameController = TextEditingController(
    text: widget.routine?.name ?? '',
  );
  late Set<int> _weekdays = widget.routine?.weekdays ?? {...everyDay};
  late TimeOfDay _time = TimeOfDay(
    hour: widget.routine?.hour ?? 9,
    minute: widget.routine?.minute ?? 0,
  );
  late List<TaskReminder> _reminders = widget.routine?.reminders ??
      const [TaskReminder(amount: 0, unit: ReminderUnit.minute)];

  bool get _isEdit => widget.routine != null;
  bool get _canSubmit =>
      _nameController.text.trim().isNotEmpty && _weekdays.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// 지금 입력값으로 만든 루틴 (새 루틴이면 새 id)
  Routine get _draft => (widget.routine ??
          Routine(
            id: newId('routine'),
            name: '',
            weekdays: const {},
            createdAt: DateTime.now(),
          ))
      .copyWithEdits(
    name: _nameController.text.trim(),
    weekdays: _weekdays,
    hour: _time.hour,
    minute: _time.minute,
    reminders: _reminders,
  );

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
      helpText: '루틴 시각 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (picked != null && mounted) setState(() => _time = picked);
  }

  void _submit() {
    if (!_canSubmit) return;
    final provider = context.read<RoutineProvider>();
    _isEdit ? provider.updateRoutine(_draft) : provider.addRoutine(_draft);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final time = DateTime(2000, 1, 1, _time.hour, _time.minute);

    return AppPage(
      title: _isEdit ? '루틴 수정' : '루틴 추가',
      closeIcon: true,
      actions: [saveAction(_canSubmit ? _submit : null)],
      slivers: [
        paddedSliver(top: 8, [
          LabeledTextField(
            label: '루틴 이름',
            controller: _nameController,
            hint: '예: 아침 업무 메일 확인',
            autofocus: !_isEdit,
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 24),
          RoutineRepeatField(
            value: _weekdays,
            onChanged: (days) => setState(() => _weekdays = days),
          ),
          const SizedBox(height: 24),
          DueDateField(
            label: '시각',
            value: time,
            valueText: formatTime(time),
            icon: Icons.schedule_rounded,
            placeholder: '시각 선택',
            onTap: _pickTime,
          ),
          const SizedBox(height: 24),
          ReminderListEditor(
            label: '리마인드 알림',
            dueDate: _draft.nextOccurrence(DateTime.now()),
            value: _reminders,
            presets: ReminderPresets.routinePresets,
            emptyMessage: '반복할 요일을 고르면 알림을 추가할 수 있어요',
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
