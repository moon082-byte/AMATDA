import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';

/// 작고 둥근 알약 모양 라벨 (방 이름, 개수, 상태 표시용)
class TagChip extends StatelessWidget {
  final String label;
  final Color foreground;
  final Color background;
  final IconData? icon;

  const TagChip({
    super.key,
    required this.label,
    required this.foreground,
    required this.background,
    this.icon,
  });

  /// 강조색(파랑) 계열 칩
  factory TagChip.accent(BuildContext context, String label, {IconData? icon}) {
    final p = context.palette;
    return TagChip(
      label: label,
      foreground: p.accent,
      background: p.accentSoft,
      icon: icon,
    );
  }

  /// 무채색 계열 칩
  factory TagChip.neutral(BuildContext context, String label, {IconData? icon}) {
    final p = context.palette;
    return TagChip(
      label: label,
      foreground: p.bodyText,
      background: p.fill,
      icon: icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppPalette.chipRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: foreground),
            const SizedBox(width: 3),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.micro.copyWith(color: foreground),
            ),
          ),
        ],
      ),
    );
  }
}
