import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// 화면 안에서 목록을 바꾸는 2~3칸짜리 탭. 선택된 칸은 [colors]의 색으로 표시한다.
class SegmentTabs extends StatelessWidget {
  final List<String> labels;
  final List<Color> colors;
  final int index;
  final ValueChanged<int> onChanged;

  const SegmentTabs({
    super.key,
    required this.labels,
    required this.colors,
    required this.index,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? palette.card : palette.border,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                button: true,
                selected: i == index,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == index
                          ? (isDark ? palette.fill : palette.card)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      labels[i],
                      style: text.body.copyWith(
                        fontWeight: FontWeight.w700,
                        color: i == index ? colors[i] : palette.subText,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
