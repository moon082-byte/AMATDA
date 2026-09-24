import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// 라이트/다크/시스템 테마를 고르는 iOS 스타일 세그먼트 컨트롤
class ThemeModeSelector extends StatelessWidget {
  final ThemeMode value;
  final ValueChanged<ThemeMode> onChanged;

  const ThemeModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _modes = [ThemeMode.system, ThemeMode.light, ThemeMode.dark];

  (String, IconData) _meta(ThemeMode mode) => switch (mode) {
        ThemeMode.system => ('시스템', Icons.brightness_auto_rounded),
        ThemeMode.light => ('라이트', Icons.light_mode_rounded),
        ThemeMode.dark => ('다크', Icons.dark_mode_rounded),
      };

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final index = _modes.indexOf(value);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: palette.fill,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          AnimatedAlign(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            alignment: Alignment(-1 + index * 1.0, 0),
            child: FractionallySizedBox(
              widthFactor: 1 / _modes.length,
              heightFactor: 1,
              child: Container(
                decoration: BoxDecoration(
                  color: isDark ? palette.checkboxIdle : palette.card,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(color: palette.shadow, blurRadius: 8),
                  ],
                ),
              ),
            ),
          ),
          Row(
            children: _modes.map((mode) {
              final selected = mode == value;
              final (label, icon) = _meta(mode);
              final color = selected ? palette.titleText : palette.subText;
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(mode),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 16, color: color),
                      const SizedBox(width: 6),
                      Text(
                        label,
                        style: text.caption.copyWith(
                          color: color,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
