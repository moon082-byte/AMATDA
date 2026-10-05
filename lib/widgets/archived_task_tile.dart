import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';
import 'common/tag_chip.dart';
import 'round_check.dart';
import 'slidable_actions.dart';

/// 아카이브 화면의 완료된 할 일 한 줄. 체크 표시를 누르거나 밀어서 '복원'하면
/// 할 일 목록의 원래 자리로 돌아간다. '삭제'는 영구 삭제.
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
          padding: const EdgeInsets.fromLTRB(12, 12, 18, 12),
          child: Row(
            children: [
              // 체크를 해제하면 진행 중 목록으로 되돌린다
              Tooltip(
                message: '체크 해제해서 되돌리기',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRestore,
                  child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: RoundCheck(isDone: true),
                  ),
                ),
              ),
              const SizedBox(width: 8),
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
