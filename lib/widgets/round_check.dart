import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// 토스 느낌의 둥근 원형 체크 버튼 (완료 시 바운스 + 체크 페이드인 애니메이션)
class RoundCheck extends StatelessWidget {
  final bool isDone;
  final double size;

  /// 체크했을 때 색 (기본은 일정 색 [AppPalette.accent])
  final Color? color;

  const RoundCheck({super.key, required this.isDone, this.size = 26, this.color});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final doneColor = color ?? palette.accent;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: isDone ? 1.1 : 1.0),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDone ? doneColor : Colors.transparent,
          border: Border.all(
            color: isDone ? doneColor : palette.checkboxIdle,
            width: 2,
          ),
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isDone ? 1 : 0,
          child: Icon(
            Icons.check_rounded,
            size: size * 0.62,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

/// 손가락으로 누르기 쉽도록 동그라미 주변([width]×44)까지 누를 수 있게 넓힌 체크 버튼
class RoundCheckButton extends StatelessWidget {
  final bool isDone;
  final VoidCallback onTap;
  final double size;
  final double width;
  final Alignment alignment;

  const RoundCheckButton({
    super.key,
    required this.isDone,
    required this.onTap,
    this.size = 26,
    this.width = 44,
    this.alignment = Alignment.center,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: width,
        height: 44,
        child: Align(
          alignment: alignment,
          child: RoundCheck(isDone: isDone, size: size),
        ),
      ),
    );
  }
}
