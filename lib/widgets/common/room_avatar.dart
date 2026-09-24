import 'package:flutter/material.dart';
import '../../models/telegram_room.dart';
import '../../theme/app_palette.dart';

/// 방마다 고정된 색을 가진 둥근 사각 아바타. 방 이름 첫 글자와 종류 아이콘을 보여준다.
class RoomAvatar extends StatelessWidget {
  final TelegramRoom room;
  final double size;

  const RoomAvatar({super.key, required this.room, this.size = 44});

  static const _tones = [
    Color(0xFF3182F6),
    Color(0xFF7B61FF),
    Color(0xFF15B371),
    Color(0xFFFE9800),
    Color(0xFFF04452),
    Color(0xFF00A6C8),
  ];

  static IconData iconFor(TelegramRoomType type) => switch (type) {
        TelegramRoomType.private => Icons.person_rounded,
        TelegramRoomType.group => Icons.groups_rounded,
        TelegramRoomType.channel => Icons.campaign_rounded,
      };

  static String typeLabel(TelegramRoomType type) => switch (type) {
        TelegramRoomType.private => '개인',
        TelegramRoomType.group => '그룹',
        TelegramRoomType.channel => '채널',
      };

  Color get tone =>
      _tones[room.id.codeUnits.fold<int>(0, (a, b) => a + b) % _tones.length];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final initial = room.name.trim().isEmpty ? '?' : room.name.trim()[0];
    final badge = size * 0.42;

    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tone.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(size * 0.34),
            ),
            child: Text(
              initial,
              style: TextStyle(
                color: tone,
                fontSize: size * 0.42,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: badge,
              height: badge,
              decoration: BoxDecoration(
                color: tone,
                shape: BoxShape.circle,
                border: Border.all(color: palette.card, width: 2),
              ),
              child: Icon(iconFor(room.type), size: badge * 0.6, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
