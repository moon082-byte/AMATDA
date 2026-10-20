import 'package:flutter/material.dart';
import '../models/project_room.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_card.dart';

/// 프로젝트방 위쪽: 초대 수락 배너(초대받은 경우), "할 일 N개가 남아있어요", 방 목표
class ProjectRoomHeader extends StatelessWidget {
  final ProjectRoom room;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const ProjectRoomHeader({
    super.key,
    required this.room,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final open = room.myOpenCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (room.invited)
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: AppCard(
              color: palette.accentSoft,
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('이 방에 초대받았어요. 수락하면 팀원이 돼요.',
                      style: text.body.copyWith(color: palette.titleText)),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(onPressed: onDecline, child: const Text('거절')),
                      FilledButton(onPressed: onAccept, child: const Text('수락')),
                    ],
                  ),
                ],
              ),
            ),
          ),
        Text.rich(
          TextSpan(
            children: open == 0
                ? const [TextSpan(text: '내 할 일을 모두 끝냈어요')]
                : [
                    const TextSpan(text: '할 일 '),
                    TextSpan(text: '$open개', style: TextStyle(color: palette.accent)),
                    const TextSpan(text: '가 남아있어요'),
                  ],
          ),
          style: text.h2,
        ),
        if (room.goal.isNotEmpty) ...[
          const SizedBox(height: 10),
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Row(
              children: [
                Icon(Icons.flag_rounded, size: 18, color: palette.routine),
                const SizedBox(width: 8),
                Expanded(child: Text(room.goal, style: text.body)),
              ],
            ),
          ),
        ],
      ],
    );
  }
}
