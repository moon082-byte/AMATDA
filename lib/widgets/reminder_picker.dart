import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task_reminder.dart';
import '../services/browser_notifications.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'field_label.dart';
import 'reminder_unit_selector.dart';

/// 할 일 리마인드 설정: "마감 [숫자][분/시간/일/주] 전" 알림.
/// 마감 기한이 없으면 켤 수 없다.
class ReminderPicker extends StatefulWidget {
  final DateTime? dueDate;
  final TaskReminder? value;
  final ValueChanged<TaskReminder?> onChanged;

  const ReminderPicker({
    super.key,
    required this.dueDate,
    required this.value,
    required this.onChanged,
  });

  @override
  State<ReminderPicker> createState() => _ReminderPickerState();
}

class _ReminderPickerState extends State<ReminderPicker> {
  static const _default = TaskReminder(amount: 30, unit: ReminderUnit.minute);
  late final _amount =
      TextEditingController(text: '${widget.value?.amount ?? 30}');

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _set(TaskReminder r) {
    final text = '${r.amount}';
    if (_amount.text != text) _amount.text = text;
    widget.onChanged(r);
  }

  void _toggle(bool on) {
    if (!on) return widget.onChanged(null);
    // 처음 켤 때 브라우저 알림 권한을 요청한다 (사용자 탭에서만 요청 가능)
    if (notificationPermission() == 'default') requestNotificationPermission();
    _set(widget.value ?? _default);
  }

  void _step(int delta) {
    final r = widget.value ?? _default;
    _set(TaskReminder(amount: (r.amount + delta).clamp(1, 999), unit: r.unit));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final due = widget.dueDate;
    final r = widget.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('리마인드 알림'),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 6, 8, 6),
          decoration: BoxDecoration(
            color: palette.fill,
            borderRadius: BorderRadius.circular(AppPalette.fieldRadius),
          ),
          child: Row(
            children: [
              Icon(Icons.notifications_rounded,
                  size: 18, color: r != null ? palette.accent : palette.subText),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  due == null ? '마감 기한을 정하면 켤 수 있어요' : '마감 전에 알림 받기',
                  style: text.body.copyWith(
                    color: due == null ? palette.subText : palette.titleText,
                  ),
                ),
              ),
              Switch(value: r != null, onChanged: due == null ? null : _toggle),
            ],
          ),
        ),
        if (r != null && due != null) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              IconButton.filledTonal(
                onPressed: () => _step(-1),
                tooltip: '줄이기',
                icon: const Icon(Icons.remove_rounded),
              ),
              SizedBox(
                width: 64,
                child: TextField(
                  controller: _amount,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  style: text.title,
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) {
                      widget.onChanged(TaskReminder(amount: n, unit: r.unit));
                    }
                  },
                ),
              ),
              IconButton.filledTonal(
                onPressed: () => _step(1),
                tooltip: '늘리기',
                icon: const Icon(Icons.add_rounded),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ReminderUnitSelector(
                  value: r.unit,
                  onChanged: (u) => _set(TaskReminder(amount: r.amount, unit: u)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ReminderPresets(selected: r, onSelected: _set),
          const SizedBox(height: 10),
          Text(
            r.fireAt(due).isBefore(DateTime.now())
                ? '알림 시각이 이미 지났어요. 저장하면 바로 알려드려요'
                : '${formatRelativeDateTime(r.fireAt(due))}에 알려드려요',
            style: text.caption.copyWith(color: palette.accent),
          ),
        ],
      ],
    );
  }
}
