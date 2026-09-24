import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import 'field_label.dart';

/// 라벨 + 둥근 배경의 텍스트 입력 필드 (바텀시트 공용)
class LabeledTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String hint;

  const LabeledTextField({
    super.key,
    required this.label,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        TextField(
          controller: controller,
          style: TextStyle(color: palette.titleText),
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: palette.background,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}
