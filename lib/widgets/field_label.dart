import 'package:flutter/material.dart';
import '../theme/app_typography.dart';

/// 입력 필드 위에 붙는 작은 라벨 텍스트 (바텀시트 공용)
class FieldLabel extends StatelessWidget {
  final String text;

  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 8),
      child: Text(text, style: context.text.label.copyWith(fontSize: 13)),
    );
  }
}
