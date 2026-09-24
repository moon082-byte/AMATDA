import 'package:flutter/material.dart';
import '../models/telegram_room.dart';
import '../theme/app_palette.dart';

/// 홈 대시보드 상단, 텔레그램 업무방 바로가기용 카드 (토스 스타일)
class TelegramRoomCard extends StatelessWidget {
  final TelegramRoom room;
  final int pendingTaskCount;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const TelegramRoomCard({
    super.key,
    required this.room,
    required this.pendingTaskCount,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 168,
      height: 156,
      child: Material(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppPalette.cardRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: palette.accentChipBackground,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: palette.accent,
                    size: 20,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  room.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: palette.titleText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '멤버 ${room.memberCount}명',
                  style: TextStyle(fontSize: 12, color: palette.subText),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.centerLeft,
                  child: pendingTaskCount > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accentChipBackground,
                            borderRadius:
                                BorderRadius.circular(AppPalette.chipRadius),
                          ),
                          child: Text(
                            '할 일 $pendingTaskCount',
                            style: TextStyle(
                              color: palette.accent,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        )
                      : Text(
                          '완료',
                          style: TextStyle(
                            color: palette.subText,
                            fontSize: 12,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
