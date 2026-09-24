import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';
import 'common/tag_chip.dart';
import 'slidable_actions.dart';

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
    final text = context.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.44,
          children: buildRestoreDeleteActions(
            context,
            onRestore: onRestore,
            onDelete: onDelete,
          ),
        ),
        child: AppCard(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: palette.successSoft,
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, size: 16, color: palette.success),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: text.title.copyWith(
                        color: palette.subText,
                        decoration: TextDecoration.lineThrough,
                        decorationColor: palette.subText,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        if (roomName != null) ...[
                          Flexible(
                            child: TagChip.neutral(
                              context,
                              roomName!,
                              icon: Icons.tag_rounded,
                            ),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(completedLabel, style: text.micro),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
