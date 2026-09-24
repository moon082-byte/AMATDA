import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/pressable.dart';

/// 목록이 페이지 크기를 넘을 때 하단에 표시하는 숫자 탭
class PageNumberTabs extends StatelessWidget {
  final int pageCount;
  final int currentPage;
  final ValueChanged<int> onPageSelected;

  const PageNumberTabs({
    super.key,
    required this.pageCount,
    required this.currentPage,
    required this.onPageSelected,
  });

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();
    final palette = context.palette;
    final text = context.text;

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: List.generate(pageCount, (index) {
          final selected = index == currentPage;
          return Pressable(
            onTap: () => onPageSelected(index),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? palette.titleText : palette.card,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${index + 1}',
                style: text.caption.copyWith(
                  color: selected ? palette.card : palette.bodyText,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
