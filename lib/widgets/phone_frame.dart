import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// 넓은 화면(PC 브라우저 등)에서 앱을 휴대폰 너비로 가운데에 표시한다.
/// 바텀시트·다이얼로그도 이 폭 안에 뜨도록 화면 크기 정보를 함께 줄인다.
class PhoneFrame extends StatelessWidget {
  static const maxWidth = 480.0;

  final Widget child;

  const PhoneFrame({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    if (media.size.width <= maxWidth) return child;

    final palette = context.palette;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final width = math.min(media.size.width, maxWidth);

    return ColoredBox(
      color: isDark ? const Color(0xFF0E0E12) : palette.border,
      child: Center(
        child: Container(
          width: width,
          decoration: BoxDecoration(
            color: palette.background,
            boxShadow: const [
              BoxShadow(color: Color(0x1A000000), blurRadius: 40),
            ],
          ),
          child: MediaQuery(
            data: media.copyWith(size: Size(width, media.size.height)),
            child: ClipRect(child: child),
          ),
        ),
      ),
    );
  }
}
