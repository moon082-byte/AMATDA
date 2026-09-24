import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';

/// 설정 화면의 카드형 그룹 컨테이너. 항목 사이에 얇은 구분선을 넣는다.
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
    final separated = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) separated.add(Divider(height: 1, color: palette.border));
      separated.add(children[i]);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text(title, style: context.text.label),
        ),
        AppCard(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: Column(children: separated),
        ),
      ],
    );
  }
}

/// 설정 그룹 안의 한 줄: 색 배경 아이콘 + 제목/설명 + 오른쪽 위젯
class SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final Widget? trailing;

  const SettingsTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final text = context.text;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: text.title.copyWith(fontSize: 15)),
                if (subtitle != null) Text(subtitle!, style: text.caption),
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
