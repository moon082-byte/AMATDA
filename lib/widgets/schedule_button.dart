import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/pressable.dart';

/// 📅 일정 버튼. 값이 없으면 아이콘만, 있으면 아이콘 옆에 [label](날짜·시간)을 붙인다.
/// [onClear]가 있으면 값 옆에 작은 지우기(X)를 둔다.
class ScheduleButton extends StatelessWidget {
  final String? label;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final IconData icon;
  final String tooltip;

  const ScheduleButton({
    super.key,
    required this.label,
    required this.onTap,
    this.onClear,
    this.icon = Icons.calendar_today_rounded,
    this.tooltip = '날짜·시간 선택',
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final value = label;
    final hasValue = value != null;

    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.96,
        child: Container(
          height: 48,
          constraints: const BoxConstraints(minWidth: 48, maxWidth: 160),
          padding: EdgeInsets.only(left: 13, right: hasValue ? 4 : 13),
          decoration: BoxDecoration(
            color: hasValue ? palette.accentSoft : palette.fill,
            borderRadius: BorderRadius.circular(AppPalette.fieldRadius),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: hasValue ? palette.accent : palette.subText),
              if (hasValue) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    value,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.caption.copyWith(
                      color: palette.accent,
                      fontWeight: FontWeight.w700,
                      height: 1.2,
                    ),
                  ),
                ),
                if (onClear != null)
                  GestureDetector(
                    onTap: onClear,
                    behavior: HitTestBehavior.opaque,
                    child: Tooltip(
                      message: '지우기',
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Icon(Icons.close_rounded,
                            size: 16, color: palette.accent),
                      ),
                    ),
                  )
                else
                  const SizedBox(width: 9),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
