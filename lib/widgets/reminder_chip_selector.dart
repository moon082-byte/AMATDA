import 'package:flutter/material.dart';
import '../models/telegram_room.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/pressable.dart';

/// 리마인더 알림 시점을 알약 모양 칩으로 선택하는 위젯
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
    final text = context.text;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: ReminderOption.values.map((option) {
        final isSelected = option == selected;
        return Pressable(
          onTap: () => onSelected(option),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            decoration: BoxDecoration(
              color: isSelected ? palette.accent : palette.fill,
              borderRadius: BorderRadius.circular(AppPalette.chipRadius),
            ),
            child: Text(
              option.label,
              style: text.caption.copyWith(
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : palette.bodyText,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
