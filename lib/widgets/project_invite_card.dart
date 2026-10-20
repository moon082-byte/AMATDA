import 'package:flutter/material.dart';
import '../models/project_room_page.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';

/// 받은 프로젝트 초대 한 장: [거절] [수락]
class ProjectInviteCard extends StatelessWidget {
  final ProjectInvite invite;
  final void Function(ProjectInvite, bool) onAnswer;

  const ProjectInviteCard({super.key, required this.invite, required this.onAnswer});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        color: palette.accentSoft,
        padding: const EdgeInsets.fromLTRB(18, 14, 10, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('📩 ${invite.invitedBy}님이 "${invite.roomName}"방에 초대했어요',
                style: context.text.body.copyWith(color: palette.titleText)),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => onAnswer(invite, false), child: const Text('거절')),
                FilledButton(onPressed: () => onAnswer(invite, true), child: const Text('수락')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
