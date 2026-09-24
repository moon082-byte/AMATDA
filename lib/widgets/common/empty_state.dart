import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';

/// 목록이 비었을 때 보여주는 아이콘 + 안내 문구
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: palette.card,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: palette.checkboxIdle),
          ),
          const SizedBox(height: 16),
          Text(title, style: text.title, textAlign: TextAlign.center),
          if (message != null) ...[
            const SizedBox(height: 4),
            Text(message!, style: text.caption, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
