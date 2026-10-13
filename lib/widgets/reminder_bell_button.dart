import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// 🔔 리마인더 버튼. 알림이 있으면 강조색 + 개수 배지로 표시한다.
class ReminderBellButton extends StatelessWidget {
  final int count;
  final VoidCallback onTap;

  /// 세부 항목 줄처럼 좁은 곳에서 쓰는 작은 모양
  final bool compact;

  const ReminderBellButton({
    super.key,
    required this.count,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final active = count > 0;
    final color = active ? palette.accent : palette.subText;
    final icon = Icon(
      active ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
      size: compact ? 18 : 22,
      color: color,
    );

    return IconButton(
      onPressed: onTap,
      tooltip: active ? '리마인더 $count개' : '리마인더 설정',
      visualDensity: compact ? VisualDensity.compact : null,
      style: compact
          ? null
          : IconButton.styleFrom(
              backgroundColor: active ? palette.accentSoft : palette.fill,
              minimumSize: const Size(48, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppPalette.fieldRadius),
              ),
            ),
      icon: Badge(
        isLabelVisible: active,
        label: Text('$count'),
        backgroundColor: palette.accent,
        offset: const Offset(6, -4),
        child: icon,
      ),
    );
  }
}
