import 'package:flutter/material.dart';
import '../models/task_reminder.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';

/// 리마인더 한 줄: [숫자 ▾][분/시간/일/주 ▾] 전 [X] + 알림 시각 안내
class ReminderDropdownRow extends StatelessWidget {
  final TaskReminder value;
  final DateTime dueDate;
  final ValueChanged<TaskReminder> onChanged;
  final VoidCallback onRemove;

  const ReminderDropdownRow({
    super.key,
    required this.value,
    required this.dueDate,
    required this.onChanged,
    required this.onRemove,
  });

  /// 단위를 바꿨을 때 지금 숫자가 그 단위에 없으면 1로 맞춘다
  void _changeUnit(ReminderUnit unit) {
    final amount =
        unit.amountOptions.contains(value.amount) ? value.amount : 1;
    onChanged(TaskReminder(amount: amount, unit: unit));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    // 예전에 직접 입력한 값(예: 7분)도 그대로 보이도록 선택지에 넣는다
    final amounts = {...value.unit.amountOptions, value.amount}.toList()..sort();
    final fireAt = value.fireAt(dueDate);

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
              _Dropdown<int>(
                value: value.amount,
                width: 76,
                items: {for (final n in amounts) n: '$n'},
                onChanged: (n) =>
                    onChanged(TaskReminder(amount: n, unit: value.unit)),
              ),
              const SizedBox(width: 8),
              _Dropdown<ReminderUnit>(
                value: value.unit,
                width: 84,
                items: {for (final u in ReminderUnit.values) u: u.label},
                onChanged: _changeUnit,
              ),
              const SizedBox(width: 8),
              Text('전', style: text.body.copyWith(color: palette.titleText)),
              const Spacer(),
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
              fireAt.isBefore(DateTime.now())
                  ? '${value.label} · 이미 지난 시각이라 저장하면 바로 알려드려요'
                  : '${value.label} · ${formatRelativeDateTime(fireAt)}에 알림',
              style: text.caption.copyWith(color: palette.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// 흰 바탕의 작은 드롭다운 상자
class _Dropdown<T> extends StatelessWidget {
  final T value;
  final double width;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  const _Dropdown({
    required this.value,
    required this.width,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: width,
      height: 40,
      padding: const EdgeInsets.only(left: 12, right: 4),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(10),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          isExpanded: true,
          menuMaxHeight: 320,
          borderRadius: BorderRadius.circular(12),
          dropdownColor: palette.card,
          style: context.text.body.copyWith(
            color: palette.titleText,
            fontWeight: FontWeight.w600,
          ),
          items: [
            for (final e in items.entries)
              DropdownMenuItem(value: e.key, child: Text(e.value)),
          ],
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
