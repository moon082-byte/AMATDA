import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/routine.dart';
import '../models/task_reminder.dart';
import '../providers/routine_provider.dart';
import '../utils/ids.dart';
import '../widgets/composer_frame.dart';
import '../widgets/reminder_bell_button.dart';
import '../widgets/reminder_popup.dart';
import '../widgets/routine_schedule_dialog.dart';
import '../widgets/schedule_button.dart';

/// 루틴 추가/수정 입력 블록: [루틴 이름][📅 반복 요일·시각][🔔 리마인더].
/// [routine]이 있으면 수정 모드로 동작한다.
class RoutineComposer extends StatefulWidget {
  final Routine? routine;

  const RoutineComposer({super.key, this.routine});

  @override
  State<RoutineComposer> createState() => _RoutineComposerState();
}

class _RoutineComposerState extends State<RoutineComposer> {
  late final _name = TextEditingController(text: widget.routine?.name ?? '');
  late Set<int> _weekdays = widget.routine?.weekdays ?? {...everyDay};
  late TimeOfDay _time = TimeOfDay(
    hour: widget.routine?.hour ?? 9,
    minute: widget.routine?.minute ?? 0,
  );
  late List<TaskReminder> _reminders = widget.routine?.reminders ??
      const [TaskReminder(amount: 0, unit: ReminderUnit.minute)];

  bool get _isEdit => widget.routine != null;
  bool get _canSubmit =>
      _name.text.trim().isNotEmpty && _weekdays.isNotEmpty;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
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
    name: _name.text.trim(),
    weekdays: _weekdays,
    hour: _time.hour,
    minute: _time.minute,
    reminders: _reminders,
  );

  Future<void> _pickSchedule() async {
    final picked = await showRoutineScheduleDialog(
      context,
      weekdays: _weekdays,
      time: _time,
    );
    if (picked == null || !mounted) return;
    setState(() {
      _weekdays = picked.weekdays;
      _time = picked.time;
    });
  }

  Future<void> _editReminders() async {
    final next = _draft.nextOccurrence(DateTime.now());
    if (next == null) return;
    final picked = await showReminderPopup(
      context,
      initial: _reminders,
      dueDate: next,
    );
    if (picked != null && mounted) setState(() => _reminders = picked);
  }

  void _submit() {
    if (!_canSubmit) return;
    final provider = context.read<RoutineProvider>();
    _isEdit ? provider.updateRoutine(_draft) : provider.addRoutine(_draft);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    return ComposerFrame(
      title: _isEdit ? '루틴 수정' : '루틴 추가',
      controller: _name,
      hint: '루틴 이름',
      autofocus: !_isEdit,
      schedule: ScheduleButton(
        label: '${draft.repeatLabel}\n${draft.timeLabel}',
        icon: Icons.event_repeat_rounded,
        tooltip: '반복 요일·시각 선택',
        onTap: _pickSchedule,
      ),
      bell: ReminderBellButton(
        count: _reminders.length,
        onTap: _editReminders,
      ),
      submitLabel: _isEdit ? '저장하기' : '추가하기',
      onSubmit: _canSubmit ? _submit : null,
    );
  }
}
