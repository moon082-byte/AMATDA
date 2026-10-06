import 'package:flutter/material.dart';
import '../models/routine.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'common/pressable.dart';
import 'field_label.dart';

/// 루틴 반복 설정: 빠른 선택(매일/평일/주말) + 요일 칩(월~일)
class RoutineRepeatField extends StatelessWidget {
  final Set<int> value;
  final ValueChanged<Set<int>> onChanged;

  const RoutineRepeatField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _quick = [
    ('매일', everyDay),
    ('평일', weekDays),
    ('주말', weekendDays),
  ];

  bool _same(Set<int> a) => a.length == value.length && a.containsAll(value);

  void _toggle(int day) {
    final next = {...value};
    if (!next.remove(day)) next.add(day);
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel('반복 · ${repeatLabelOf(value)}'),
        Row(
          children: [
            for (final (label, days) in _quick) ...[
              Expanded(
                child: ChoiceChip(
                  selected: _same(days),
                  onSelected: (_) => onChanged({...days}),
                  showCheckmark: false,
                  label: SizedBox(
                    width: double.infinity,
                    child: Text(label, textAlign: TextAlign.center),
                  ),
                ),
              ),
              if (label != _quick.last.$1) const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            for (var day = 1; day <= 7; day++)
              _DayChip(
                label: koWeekdays[day - 1],
                selected: value.contains(day),
                weekend: day >= 6,
                onTap: () => _toggle(day),
              ),
          ],
        ),
        if (value.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '반복할 요일을 하나 이상 골라 주세요',
              style: text.caption.copyWith(color: palette.danger),
            ),
          ),
      ],
    );
  }
}

/// 요일 동그라미 칩
class _DayChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool weekend;
  final VoidCallback onTap;

  const _DayChip({
    required this.label,
    required this.selected,
    required this.weekend,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    return Semantics(
      button: true,
      selected: selected,
      label: '$label요일',
      child: Pressable(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? palette.routine : palette.fill,
            shape: BoxShape.circle,
          ),
          child: Text(
            label,
            style: text.body.copyWith(
              fontWeight: FontWeight.w700,
              color: selected
                  ? Colors.white
                  : weekend
                      ? palette.danger
                      : palette.bodyText,
            ),
          ),
        ),
      ),
    );
  }
}
