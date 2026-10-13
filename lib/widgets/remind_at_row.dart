import 'package:flutter/material.dart';
import '../services/reminder_checker.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'reminder_pick_button.dart';

/// 리마인더 한 줄: [📅 날짜][🕐 시간][X] + 알림 시각 안내
class RemindAtRow extends StatelessWidget {
  final DateTime value;

  /// 마감 일시 (있으면 "마감 N 전" 안내를 붙인다)
  final DateTime? dueDate;
  final ValueChanged<DateTime> onChanged;
  final VoidCallback onRemove;

  const RemindAtRow({
    super.key,
    required this.value,
    required this.dueDate,
    required this.onChanged,
    required this.onRemove,
  });

  Future<void> _pickDate(BuildContext context) async {
    final now = DateTime.now();
    final first = DateTime(now.year - 1, now.month, now.day);
    final date = await showDatePicker(
      context: context,
      initialDate: value.isBefore(first) ? now : value,
      firstDate: first,
      lastDate: DateTime(now.year + 2, now.month, now.day),
      helpText: '리마인드 날짜 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (date == null) return;
    onChanged(DateTime(date.year, date.month, date.day, value.hour, value.minute));
  }

  Future<void> _pickTime(BuildContext context) async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
      helpText: '리마인드 시간 선택',
      cancelText: '취소',
      confirmText: '확인',
    );
    if (time == null) return;
    onChanged(DateTime(value.year, value.month, value.day, time.hour, time.minute));
  }

  String get _caption {
    if (value.isBefore(DateTime.now())) return '이미 지난 시각이라 저장하면 바로 알려드려요';
    final due = dueDate;
    final when = '${formatRelativeDateTime(value)}에 알림';
    if (due == null) return when;
    if (value.isAfter(due)) return '$when · 마감 이후';
    return '$when · 마감 ${formatRemaining(due.difference(value))} 전';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final date =
        '${value.month}/${value.day} (${koWeekdayShort(value)})';

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 6, 2, 8),
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(AppPalette.fieldRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ReminderPickButton(
                  icon: Icons.calendar_today_rounded,
                  label: date,
                  tooltip: '리마인드 날짜',
                  onTap: () => _pickDate(context),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                flex: 2,
                child: ReminderPickButton(
                  icon: Icons.schedule_rounded,
                  label: formatTime(value),
                  tooltip: '리마인드 시간',
                  onTap: () => _pickTime(context),
                ),
              ),
              IconButton(
                onPressed: onRemove,
                tooltip: '이 알림 지우기',
                icon: Icon(Icons.close_rounded, size: 20, color: palette.subText),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 2, top: 4),
            child: Text(
              _caption,
              style: text.caption.copyWith(color: palette.accent),
            ),
          ),
        ],
      ),
    );
  }
}
