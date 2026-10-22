import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/profile.dart';
import '../models/project.dart';
import '../models/project_room.dart';
import '../theme/app_typography.dart';
import 'handle_invite_field.dart';
import 'profile_avatar.dart';
import 'project_member_card.dart';
import 'project_task_row.dart';
import 'slidable_actions.dart';

/// 방 화면 [팀원] 탭: 팀원별 [진행 중](기본 펼침)·[완료](기본 접힘) 업무.
/// 팀장은 맨 위에서 닉네임#태그로 초대하고, 팀원 카드를 밀어 내보내거나 초대를 취소한다.
class ProjectMembersTab extends StatelessWidget {
  final ProjectRoom room;
  final TaskRowActions actions;
  final void Function(String userId) onInvite;
  final void Function(ProjectMember member) onRemove;

  const ProjectMembersTab({
    super.key,
    required this.room,
    required this.actions,
    required this.onInvite,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final invited = [for (final m in room.members) if (m.invited) m];
    final unassigned = room.tasksOf(null);
    Widget swipeToRemove(ProjectMember m, Widget child) => Slidable(
          key: ValueKey(m.userId),
          enabled: room.isLeader && !m.isLeader,
          endActionPane: ActionPane(
            motion: const DrawerMotion(),
            extentRatio: 0.26,
            children: buildDangerAction(context,
                icon: Icons.person_remove_rounded,
                label: m.invited ? '초대 취소' : '내보내기',
                onTap: () => onRemove(m)),
          ),
          child: child,
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (room.isLeader) ...[
          HandleInviteField(onFound: (userId, _) => onInvite(userId)),
          const SizedBox(height: 12),
        ],
        for (final m in room.activeMembers)
          swipeToRemove(
            m,
            ProjectMemberCard(
              title: m.handle,
              avatar: ProfileAvatar(profile: Profile(nickname: m.nickname), size: 34),
              badge: m.isLeader ? '팀장' : m.userId == room.myId ? '나' : null,
              tasks: room.tasksOf(m.userId),
              actions: actions,
            ),
          ),
        if (unassigned.isNotEmpty)
          ProjectMemberCard(
            title: '담당자 없음',
            avatar: const CircleAvatar(radius: 17, child: Icon(Icons.help_outline_rounded, size: 18)),
            tasks: unassigned,
            actions: actions,
          ),
        if (invited.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 0, 6),
            child: Text('초대 중 · 수락을 기다려요', style: text.caption),
          ),
          for (final m in invited)
            swipeToRemove(
              m,
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                leading: ProfileAvatar(profile: Profile(nickname: m.nickname), size: 32),
                title: Text(m.handle),
              ),
            ),
        ],
      ],
    );
  }
}
