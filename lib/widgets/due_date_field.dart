import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'common/pressable.dart';
import 'field_label.dart';

/// 라벨 + 탭하면 날짜/시간을 고르는 필드 (바텀시트 공용).
/// 값이 있으면 오른쪽에 지우기 버튼을 보여준다.
class DueDateField extends StatelessWidget {
  final String label;
  final DateTime? value;
  final String placeholder;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const DueDateField({
    super.key,
    required this.label,
    required this.value,
    required this.placeholder,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final hasValue = value != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(label),
        Pressable(
          onTap: onTap,
          pressedScale: 0.98,
          child: Container(
            height: 52,
            padding: const EdgeInsets.only(left: 16, right: 6),
            decoration: BoxDecoration(
              color: palette.fill,
              borderRadius: BorderRadius.circular(AppPalette.fieldRadius),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_rounded,
                  size: 18,
                  color: hasValue ? palette.accent : palette.subText,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    hasValue ? formatRelativeDateTime(value!) : placeholder,
                    style: text.body.copyWith(
                      color: hasValue ? palette.titleText : palette.subText,
                    ),
                  ),
                ),
                if (hasValue && onClear != null)
                  IconButton(
                    onPressed: onClear,
                    tooltip: '마감 기한 지우기',
                    icon: Icon(
                      Icons.cancel_rounded,
                      size: 20,
                      color: palette.checkboxIdle,
                    ),
                  )
                else
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      color: palette.subText,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
