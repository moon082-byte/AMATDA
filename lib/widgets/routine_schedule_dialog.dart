import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'due_date_field.dart';
import 'routine_repeat_field.dart';

/// 루틴 📅 팝업: 반복 요일과 시각을 고른다. 취소하면 null.
Future<({Set<int> weekdays, TimeOfDay time})?> showRoutineScheduleDialog(
  BuildContext context, {
  required Set<int> weekdays,
  required TimeOfDay time,
}) {
  return showDialog(
    context: context,
    builder: (_) => _RoutineScheduleDialog(weekdays: weekdays, time: time),
  );
}

class _RoutineScheduleDialog extends StatefulWidget {
  final Set<int> weekdays;
  final TimeOfDay time;

  const _RoutineScheduleDialog({required this.weekdays, required this.time});

  @override
  State<_RoutineScheduleDialog> createState() => _RoutineScheduleDialogState();
}

class _RoutineScheduleDialogState extends State<_RoutineScheduleDialog> {
  late Set<int> _weekdays = {...widget.weekdays};
  late TimeOfDay _time = widget.time;

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

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final time = DateTime(2000, 1, 1, _time.hour, _time.minute);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('반복 요일 · 시각', style: context.text.h2),
            const SizedBox(height: 20),
            RoutineRepeatField(
              value: _weekdays,
              onChanged: (days) => setState(() => _weekdays = days),
            ),
            const SizedBox(height: 20),
            DueDateField(
              label: '시각',
              value: time,
              valueText: formatTime(time),
              icon: Icons.schedule_rounded,
              placeholder: '시각 선택',
              onTap: _pickTime,
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.fill,
                      foregroundColor: palette.bodyText,
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _weekdays.isEmpty
                        ? null
                        : () => Navigator.pop(
                            context, (weekdays: _weekdays, time: _time)),
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
