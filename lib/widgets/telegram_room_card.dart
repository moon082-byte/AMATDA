import 'package:flutter/material.dart';
import '../models/telegram_room.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';
import 'common/due_badge.dart';
import 'common/pressable.dart';
import 'common/room_avatar.dart';
import 'common/tag_chip.dart';

const _cardWidth = 172.0;

/// '오늘 할일' 상단 캐러셀의 텔레그램 업무방 바로가기 카드
class TelegramRoomCard extends StatelessWidget {
  final TelegramRoom room;
  final int pendingTaskCount;
  final int totalTaskCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const TelegramRoomCard({
    super.key,
    required this.room,
    required this.pendingTaskCount,
    required this.totalTaskCount,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return Padding(
      padding: const EdgeInsets.only(right: 10),
      child: SizedBox(
        width: _cardWidth,
        child: AppCard(
          onTap: onTap,
          onLongPress: onLongPress,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RoomAvatar(room: room, size: 40),
                  const Spacer(),
                  if (room.dueDate != null)
                    DueBadge(dueDate: room.dueDate, dDay: true),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                room.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: text.title.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 2),
              Text(
                '${RoomAvatar.typeLabel(room.type)} · 멤버 ${room.memberCount}명',
                style: text.caption,
              ),
              const Spacer(),
              _statusChip(context, palette),
            ],
          ),
        ),
      ),
    );
  }

  /// 남은 할 일 수 / 모두 완료 / 할 일 없음 상태 칩
  Widget _statusChip(BuildContext context, AppPalette palette) {
    if (totalTaskCount == 0) return TagChip.neutral(context, '할 일 없음');
    if (pendingTaskCount > 0) {
      return TagChip.accent(context, '할 일 $pendingTaskCount개');
    }
    return TagChip(
      label: '모두 완료',
      foreground: palette.success,
      background: palette.successSoft,
      icon: Icons.check_rounded,
    );
  }
}

/// 캐러셀 마지막의 '새 업무방' 추가 카드
class AddRoomCard extends StatelessWidget {
  final VoidCallback onTap;

  const AddRoomCard({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Pressable(
      onTap: onTap,
      child: Container(
        width: 120,
        decoration: BoxDecoration(
          color: palette.card.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(AppPalette.cardRadius),
          border: Border.all(color: palette.border, width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add_rounded, color: palette.accent),
            ),
            const SizedBox(height: 10),
            Text('새 업무방', style: context.text.label),
          ],
        ),
      ),
    );
  }
}
