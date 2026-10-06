import 'package:flutter/material.dart';
import '../models/task_reminder.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/pressable.dart';

/// 리마인드 단위(분/시간/일/주)를 고르는 작은 세그먼트
class ReminderUnitSelector extends StatelessWidget {
  final ReminderUnit value;
  final ValueChanged<ReminderUnit> onChanged;

  const ReminderUnitSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return Container(
      height: 44,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: ReminderUnit.values.map((unit) {
          final selected = unit == value;
          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => onChanged(unit),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? palette.card : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  unit.label,
                  style: text.caption.copyWith(
                    fontWeight: FontWeight.w700,
                    color: selected ? palette.titleText : palette.subText,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// 자주 쓰는 리마인드 값 바로가기 칩. 누르면 알림이 하나 추가된다(이미 있으면 표시만).
class ReminderPresets extends StatelessWidget {
  final List<TaskReminder> selected;
  final ValueChanged<TaskReminder> onSelected;
  final List<TaskReminder> presets;

  const ReminderPresets({
    super.key,
    required this.selected,
    required this.onSelected,
    this.presets = taskPresets,
  });

  /// 할 일·업무방용 (마감 전 알림)
  static const taskPresets = [
    TaskReminder(amount: 0, unit: ReminderUnit.minute),
    TaskReminder(amount: 10, unit: ReminderUnit.minute),
    TaskReminder(amount: 30, unit: ReminderUnit.minute),
    TaskReminder(amount: 1, unit: ReminderUnit.hour),
    TaskReminder(amount: 1, unit: ReminderUnit.day),
    TaskReminder(amount: 1, unit: ReminderUnit.week),
  ];

  /// 루틴용 (매번 정해 둔 시각 기준)
  static const routinePresets = [
    TaskReminder(amount: 0, unit: ReminderUnit.minute),
    TaskReminder(amount: 5, unit: ReminderUnit.minute),
    TaskReminder(amount: 10, unit: ReminderUnit.minute),
    TaskReminder(amount: 30, unit: ReminderUnit.minute),
    TaskReminder(amount: 1, unit: ReminderUnit.hour),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: presets.map((p) {
        final isSelected = selected.contains(p);
        return Pressable(
          onTap: isSelected ? null : () => onSelected(p),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: isSelected ? palette.accentSoft : palette.fill,
              borderRadius: BorderRadius.circular(AppPalette.chipRadius),
            ),
            child: Text(
              isSelected ? '✓ ${p.label}' : '+ ${p.label}',
              style: text.micro.copyWith(
                color: isSelected ? palette.accent : palette.bodyText,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
