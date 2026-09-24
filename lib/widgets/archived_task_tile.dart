import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../theme/app_palette.dart';

/// 아카이브 화면의 완료된 할 일 한 줄. 슬라이드하면 '복원'/'삭제' 버튼이 나타난다.
class ArchivedTaskTile extends StatelessWidget {
  final String title;
  final String? roomName;
  final String completedLabel;
  final VoidCallback onRestore;
  final VoidCallback onDelete;

  const ArchivedTaskTile({
    super.key,
    required this.title,
    required this.roomName,
    required this.completedLabel,
    required this.onRestore,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Slidable(
      endActionPane: ActionPane(
        motion: const DrawerMotion(),
        extentRatio: 0.42,
        children: [
          SlidableAction(
            onPressed: (_) => onRestore(),
            backgroundColor: palette.accent,
            foregroundColor: Colors.white,
            icon: Icons.replay,
            label: '복원',
            borderRadius: BorderRadius.circular(20),
          ),
          SlidableAction(
            onPressed: (_) => onDelete(),
            backgroundColor: const Color(0xFFFF5B5B),
            foregroundColor: Colors.white,
            icon: Icons.delete_outline,
            label: '삭제',
            borderRadius: BorderRadius.circular(20),
          ),
        ],
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: BorderRadius.circular(AppPalette.cardRadius),
        ),
        child: Row(
          children: [
            Icon(Icons.check_circle, color: palette.accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.lineThrough,
                      color: palette.subText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (roomName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: palette.accentChipBackground,
                            borderRadius:
                                BorderRadius.circular(AppPalette.chipRadius),
                          ),
                          child: Text(
                            roomName!,
                            style: TextStyle(
                              fontSize: 11,
                              color: palette.accent,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        completedLabel,
                        style: TextStyle(fontSize: 12, color: palette.subText),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
