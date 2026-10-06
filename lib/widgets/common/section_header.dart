import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';

/// 목록 위에 붙는 섹션 제목. 개수 배지와 오른쪽 액션을 선택적으로 표시한다.
class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final Widget? trailing;

  /// 개수 배지 색 (기본은 일정 색)
  final Color? countColor;

  /// 제목 앞 작은 색 점 (일정/루틴 구분용)
  final Color? dotColor;

  const SectionHeader({
    super.key,
    required this.title,
    this.count,
    this.trailing,
    this.countColor,
    this.dotColor,
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
            if (dotColor != null) ...[
              Container(
                width: 8,
                height: 8,
                decoration:
                    BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
            ],
            Text(title, style: text.title.copyWith(fontWeight: FontWeight.w700)),
            if (count != null) ...[
              const SizedBox(width: 6),
              Text(
                '$count',
                style: text.title.copyWith(
                  color: countColor ?? palette.accent,
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
