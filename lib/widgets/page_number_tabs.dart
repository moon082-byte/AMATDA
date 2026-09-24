import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

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

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: List.generate(pageCount, (index) {
          final selected = index == currentPage;
          return GestureDetector(
            onTap: () => onPageSelected(index),
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? palette.accent : palette.card,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? palette.accent : palette.checkboxIdle,
                ),
              ),
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: selected ? Colors.white : palette.subText,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
