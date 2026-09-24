import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// 메인 화면의 '오늘 할일' / '완료된 일들' 2x1 배너 카드
class DashboardBanner extends StatelessWidget {
  final String title;
  final String countLabel;
  final IconData icon;
  final VoidCallback onTap;

  const DashboardBanner({
    super.key,
    required this.title,
    required this.countLabel,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Material(
      color: palette.card,
      borderRadius: BorderRadius.circular(AppPalette.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.accentChipBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: palette.accent, size: 20),
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                  color: palette.subText,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                countLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                  color: palette.titleText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
