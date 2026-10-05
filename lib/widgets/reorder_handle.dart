import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// 감싼 영역을 꾹 누르면 드래그 정렬이 시작된다. [index]가 null이면 그대로 표시만 한다.
class ReorderHandle extends StatelessWidget {
  final int? index;
  final Widget child;

  const ReorderHandle({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final i = index;
    if (i == null) return child;
    return ReorderableDelayedDragStartListener(index: i, child: child);
  }
}

/// 순서를 바꿀 수 있다는 표시(세로 점 6개). 꾹 누르면 옮길 수 있다는 힌트.
class DragGrip extends StatelessWidget {
  const DragGrip({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Icon(
        Icons.drag_indicator_rounded,
        size: 20,
        color: context.palette.checkboxIdle,
      ),
    );
  }
}

/// 드래그 중인 항목을 살짝 띄워 보이게 하는 장식 (SliverReorderableList.proxyDecorator)
Widget liftedProxy(Widget child, int index, Animation<double> animation) {
  return AnimatedBuilder(
    animation: animation,
    builder: (context, child) {
      final t = Curves.easeOut.transform(animation.value);
      return Transform.scale(
        scale: 1 + 0.03 * t,
        child: Material(
          type: MaterialType.transparency,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppPalette.cardRadius),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18 * t),
                  blurRadius: 24,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: child,
          ),
        ),
      );
    },
    child: child,
  );
}
