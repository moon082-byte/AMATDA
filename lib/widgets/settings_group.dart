import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// 설정 화면의 카드형 그룹 리스트 컨테이너
class SettingsGroup extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const SettingsGroup({
    super.key,
    required this.title,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: palette.subText,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: palette.card,
            borderRadius: BorderRadius.circular(AppPalette.cardRadius),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}
