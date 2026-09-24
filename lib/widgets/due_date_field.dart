import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import 'field_label.dart';

/// 라벨 + 탭하면 날짜/시간을 고르는 필드 (바텀시트 공용)
class DueDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String placeholder;
  final VoidCallback onTap;

  const DueDateField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  String _format(DateTime date) {
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$m/$d $h:$min';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Icon(Icons.event_outlined, size: 18, color: palette.subText),
                const SizedBox(width: 8),
                Text(
                  value == null ? placeholder : _format(value!),
                  style: TextStyle(color: palette.subText),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
