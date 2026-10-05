import 'package:flutter/material.dart';
import '../services/reminder_checker.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// 화면 위쪽에서 내려오는 리마인드 배너 (앱이 열려 있을 때)
class ReminderBanner extends StatelessWidget {
  final DueReminder reminder;
  final int moreCount;
  final VoidCallback onClose;

  const ReminderBanner({
    super.key,
    required this.reminder,
    required this.moreCount,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return Material(
      color: palette.card,
      elevation: 8,
      shadowColor: Colors.black26,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onClose,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: palette.warningSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  color: palette.warning,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reminder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.title.copyWith(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      moreCount > 0
                          ? '${reminder.body} · 외 $moreCount개'
                          : reminder.body,
                      style: text.caption,
                    ),
                  ],
                ),
              ),
              // 배너는 Navigator 바깥(Overlay 없음)에 떠 있어서 툴팁을 쓸 수 없다
              IconButton(
                onPressed: onClose,
                icon: Icon(
                  Icons.close_rounded,
                  color: palette.subText,
                  semanticLabel: '닫기',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
