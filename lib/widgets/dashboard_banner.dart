import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';

/// 메인 화면의 '오늘 할일' / '완료된 일들' 요약 타일
class DashboardBanner extends StatelessWidget {
  final String title;
  final int count;
  final IconData icon;
  final Color color;
  final Color softColor;
  final VoidCallback onTap;

  const DashboardBanner({
    super.key,
    required this.title,
    required this.count,
    required this.icon,
    required this.color,
    required this.softColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: softColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const Spacer(),
              Icon(Icons.chevron_right_rounded, color: palette.checkboxIdle),
            ],
          ),
          const SizedBox(height: 16),
          Text(title, style: text.label),
          const SizedBox(height: 2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '$count', style: text.display),
                TextSpan(
                  text: ' 개',
                  style: text.title.copyWith(color: palette.subText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
