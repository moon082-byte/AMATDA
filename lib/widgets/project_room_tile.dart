import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

import '../models/project_room_page.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';
import 'common/progress_bar.dart';
import 'common/tag_chip.dart';
import 'slidable_actions.dart';

/// 프로젝트 목록의 방 한 칸: 이름·목표, 팀장 표시, 팀원 수, 내 남은 할 일, 달성률.
/// 팀장인 방은 밀어서 [수정][삭제].
class ProjectRoomTile extends StatelessWidget {
  final ProjectRoomSummary room;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const ProjectRoomTile({
    super.key,
    required this.room,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        key: ValueKey(room.id),
        enabled: room.isLeader,
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.44,
          children: buildEditDeleteActions(
            context,
            onEdit: onEdit,
            onDelete: onDelete,
          ),
        ),
        child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      room.name,
                      style: text.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (room.isLeader)
                    TagChip.accent(context, '팀장', icon: Icons.star_rounded),
                ],
              ),
              if (room.goal.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  room.goal,
                  style: text.caption,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 12),
              ProgressBar(value: room.progress, height: 6),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.group_rounded, size: 15, color: palette.subText),
                  const SizedBox(width: 4),
                  Text('${room.members}명', style: text.caption),
                  const SizedBox(width: 12),
                  Text('달성 ${room.done}/${room.total}', style: text.caption),
                  const Spacer(),
                  if (room.myOpen > 0)
                    Text(
                      '내 할 일 ${room.myOpen}개',
                      style: text.caption.copyWith(
                        color: palette.accent,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
