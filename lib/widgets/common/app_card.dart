import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';
import 'pressable.dart';

/// 앱 공용 카드 표면. 라이트 모드에서는 은은한 그림자, 다크 모드에서는 평면으로 표시한다.
/// [onTap]이 있으면 누를 때 살짝 줄어드는 피드백을 준다.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final Border? border;
  final double radius;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.onTap,
    this.onLongPress,
    this.color,
    this.border,
    this.radius = AppPalette.cardRadius,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    final card = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? palette.card,
        borderRadius: BorderRadius.circular(radius),
        border: border,
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 24,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null && onLongPress == null) return card;
    return Pressable(onTap: onTap, onLongPress: onLongPress, child: card);
  }
}
