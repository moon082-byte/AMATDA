import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// 입력 필드 위에 붙는 작은 라벨 텍스트 (바텀시트 공용)
class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: palette.subText,
        ),
      ),
    );
  }
}
