import 'package:flutter/material.dart';
import '../models/telegram_room.dart';
import '../theme/app_palette.dart';
import '../utils/d_day.dart';

/// 업무방 상세 화면 상단의 D-Day 배지 + '텔레그램 방 열기' 버튼
class RoomDetailHeader extends StatelessWidget {
  final TelegramRoom room;

  const RoomDetailHeader({super.key, required this.room});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: palette.accentChipBackground,
            borderRadius: BorderRadius.circular(AppPalette.chipRadius),
          ),
          child: Text(
            formatDDay(room.dueDate),
            style: TextStyle(
              color: palette.accent,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => debugPrint('텔레그램 방 링크 이동: ${room.inviteLink}'),
            icon: const Icon(Icons.send_rounded, size: 16),
            label: const Text('텔레그램 방 열기'),
            style: OutlinedButton.styleFrom(
              foregroundColor: palette.accent,
              side: BorderSide(color: palette.accent),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
