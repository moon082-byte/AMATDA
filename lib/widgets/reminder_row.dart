import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/task_reminder.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'reminder_unit_selector.dart';

/// 리마인드 한 줄: [−] 숫자 [+] [분/시간/일/주] [X] + 알림 시각 안내
class ReminderRow extends StatefulWidget {
  final TaskReminder value;
  final DateTime dueDate;
  final ValueChanged<TaskReminder> onChanged;
  final VoidCallback onRemove;

  const ReminderRow({
    super.key,
    required this.value,
    required this.dueDate,
    required this.onChanged,
    required this.onRemove,
  });

  @override
  State<ReminderRow> createState() => _ReminderRowState();
}

class _ReminderRowState extends State<ReminderRow> {
  late final _amount = TextEditingController(text: '${widget.value.amount}');

  @override
  void didUpdateWidget(ReminderRow old) {
    super.didUpdateWidget(old);
    final text = '${widget.value.amount}';
    if (_amount.text != text && int.tryParse(_amount.text) != widget.value.amount) {
      _amount.text = text;
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final r = widget.value;
    final amount = (r.amount + delta).clamp(0, 999);
    _amount.text = '$amount';
    widget.onChanged(TaskReminder(amount: amount, unit: r.unit));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final r = widget.value;
    final fireAt = r.fireAt(widget.dueDate);

    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 4, 10),
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(AppPalette.fieldRadius),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => _step(-1),
                tooltip: '줄이기',
                icon: const Icon(Icons.remove_rounded, size: 20),
              ),
              SizedBox(
                width: 44,
                child: TextField(
                  controller: _amount,
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(3),
                  ],
                  style: text.title,
                  decoration: const InputDecoration(
                    filled: false,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n >= 0) {
                      widget.onChanged(TaskReminder(amount: n, unit: r.unit));
                    }
                  },
                ),
              ),
              IconButton(
                onPressed: () => _step(1),
                tooltip: '늘리기',
                icon: const Icon(Icons.add_rounded, size: 20),
              ),
              Expanded(
                child: ReminderUnitSelector(
                  value: r.unit,
                  onChanged: (u) =>
                      widget.onChanged(TaskReminder(amount: r.amount, unit: u)),
                ),
              ),
              IconButton(
                onPressed: widget.onRemove,
                tooltip: '이 알림 지우기',
                icon: Icon(Icons.close_rounded, size: 20, color: palette.subText),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: Text(
              fireAt.isBefore(DateTime.now())
                  ? '${r.label} · 이미 지난 시각이라 저장하면 바로 알려드려요'
                  : '${r.label} · ${formatRelativeDateTime(fireAt)}에 알림',
              style: text.caption.copyWith(color: palette.accent),
            ),
          ),
        ],
      ),
    );
  }
}
