import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// 토스 느낌의 둥근 원형 체크 버튼 (완료 시 바운스 + 체크 페이드인 애니메이션)
class RoundCheck extends StatelessWidget {
  final bool isDone;

  const RoundCheck({super.key, required this.isDone});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 1.0, end: isDone ? 1.12 : 1.0),
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isDone ? palette.accent : Colors.transparent,
          border: Border.all(
            color: isDone ? palette.accent : palette.checkboxIdle,
            width: 2,
          ),
        ),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 150),
          opacity: isDone ? 1 : 0,
          child: const Icon(Icons.check, size: 16, color: Colors.white),
        ),
      ),
    );
  }
}
