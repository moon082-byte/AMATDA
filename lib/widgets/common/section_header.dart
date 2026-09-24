import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';

/// 목록 위에 붙는 섹션 제목. 개수 배지와 오른쪽 액션을 선택적으로 표시한다.
class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 12),
      child: SizedBox(
        height: 32,
        child: Row(
          children: [
            Text(title, style: text.title.copyWith(fontWeight: FontWeight.w700)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: text.title.copyWith(
                  color: palette.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
            const Spacer(),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
