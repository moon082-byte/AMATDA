import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'field_label.dart';

/// 라벨 + 둥근 배경의 텍스트 입력 필드 (바텀시트 공용).
/// 모양은 테마의 inputDecorationTheme을 따른다.
class LabeledTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;
  final bool autofocus;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onSubmitted;

  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
    this.autofocus = false,
    this.keyboardType,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        TextField(
          controller: controller,
          autofocus: autofocus,
          keyboardType: keyboardType,
          onSubmitted: onSubmitted,
          style: context.text.body.copyWith(color: context.palette.titleText),
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}
