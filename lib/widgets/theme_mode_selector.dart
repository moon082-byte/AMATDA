import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// 라이트/다크/시스템 테마를 고르는 세그먼트 형태의 선택 위젯
class ThemeModeSelector extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  const ThemeModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  String _label(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return '라이트';
      case ThemeMode.dark:
        return '다크';
      case ThemeMode.system:
        return '시스템';
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: ThemeMode.values.map((mode) {
          final selected = mode == value;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: GestureDetector(
                onTap: () => onChanged(mode),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: selected
                        ? palette.accentChipBackground
                        : palette.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: selected ? palette.accent : Colors.transparent,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _label(mode),
                    style: TextStyle(
                      color: selected ? palette.accent : palette.subText,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
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
