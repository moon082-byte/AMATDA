import 'package:flutter/material.dart';
import '../models/telegram_room.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';
import 'common/due_badge.dart';
import 'common/progress_bar.dart';
import 'common/room_avatar.dart';
import 'common/tag_chip.dart';

/// 업무방 상세 화면 상단 요약 카드: 방 정보, 마감 D-Day, 진행률, 텔레그램 열기 버튼
class RoomDetailHeader extends StatelessWidget {
  final TelegramRoom room;
  final int totalCount;
  final int doneCount;

  const RoomDetailHeader({
    super.key,
    required this.room,
    required this.totalCount,
    required this.doneCount,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final progress = totalCount == 0 ? 0.0 : doneCount / totalCount;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RoomAvatar(room: room, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${RoomAvatar.typeLabel(room.type)} · 멤버 ${room.memberCount}명',
                      style: text.caption,
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        DueBadge(dueDate: room.dueDate, dDay: true),
                        if (room.reminderOption != ReminderOption.none)
                          TagChip.neutral(
                            context,
                            room.reminderOption.label,
                            icon: Icons.notifications_rounded,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Text('진행률', style: text.label),
              const Spacer(),
              Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$doneCount',
                      style: TextStyle(color: palette.accent),
                    ),
                    TextSpan(text: ' / $totalCount'),
                  ],
                ),
                style: text.label.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ProgressBar(value: progress),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => debugPrint('텔레그램 방 링크 이동: ${room.inviteLink}'),
            style: FilledButton.styleFrom(
              backgroundColor: palette.accentSoft,
              foregroundColor: palette.accent,
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('텔레그램에서 열기'),
          ),
        ],
      ),
    );
  }
}
