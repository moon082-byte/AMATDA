import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';

/// 메인 화면 인사말: 오늘 날짜와 남은 할 일 개수 ("할 일 3개가 남아 있어요")
class DashboardGreeting extends StatelessWidget {
  final int pending;
  const DashboardGreeting({super.key, required this.pending});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(formatFullDate(DateTime.now()), style: text.label),
          const SizedBox(height: 6),
          Text.rich(
            TextSpan(
              children: pending == 0
                  ? const [TextSpan(text: '오늘 할 일을\n모두 끝냈어요')]
                  : [
                      const TextSpan(text: '할 일 '),
                      TextSpan(text: '$pending개', style: TextStyle(color: palette.accent)),
                      const TextSpan(text: '가\n남아 있어요'),
                    ],
            ),
            style: text.h1,
          ),
        ],
      ),
    );
  }
}
