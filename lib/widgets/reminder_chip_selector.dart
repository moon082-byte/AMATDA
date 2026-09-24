import 'package:flutter/material.dart';

import '../models/telegram_room.dart';
import '../theme/app_palette.dart';

/// 리마인더 알림 시점을 칩(Chip) 형태로 선택하는 위젯
class ReminderChipSelector extends StatelessWidget {
  final ReminderOption selected;
  final ValueChanged<ReminderOption> onSelected;

  const ReminderChipSelector({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ReminderOption.values.map((option) {
        final isSelected = option == selected;
        return ChoiceChip(
          label: Text(option.label),
          selected: isSelected,
          onSelected: (_) => onSelected(option),
          showCheckmark: false,
          selectedColor: palette.accentChipBackground,
          backgroundColor: palette.background,
          labelStyle: TextStyle(
            color: isSelected ? palette.accent : palette.subText,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppPalette.chipRadius),
            side: BorderSide(
              color: isSelected ? palette.accent : Colors.transparent,
            ),
          ),
        );
      }).toList(),
    );
  }
}
