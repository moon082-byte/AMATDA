import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../models/project.dart';
import '../models/project_room.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';
import 'common/progress_bar.dart';
import 'profile_avatar.dart';
import 'project_task_row.dart';

/// 방 화면 [팀원] 탭: 팀원별로 배정 업무를 한눈에 (진행 중 먼저, 진행률 막대). 담당자 없는 업무는 따로.
class ProjectMembersTab extends StatelessWidget {
  final ProjectRoom room;
  final TaskRowActions actions;

  const ProjectMembersTab({super.key, required this.room, required this.actions});

  @override
  Widget build(BuildContext context) {
    final unassigned = room.tasksOf(null);
    return Column(
      children: [
        for (final m in room.activeMembers)
          _MemberCard(
            title: m.handle,
            avatar: ProfileAvatar(profile: Profile(nickname: m.nickname), size: 34),
            badge: m.isLeader ? '팀장' : m.userId == room.myId ? '나' : null,
            tasks: room.tasksOf(m.userId),
            actions: actions,
          ),
        if (unassigned.isNotEmpty)
          _MemberCard(
            title: '담당자 없음',
            avatar: const CircleAvatar(radius: 17, child: Icon(Icons.help_outline_rounded, size: 18)),
            tasks: unassigned,
            actions: actions,
          ),
      ],
    );
  }
}

class _MemberCard extends StatelessWidget {
  final String title;
  final Widget avatar;
  final String? badge;
  final List<ProjectTask> tasks;
  final TaskRowActions actions;

  const _MemberCard({
    required this.title,
    required this.avatar,
    required this.tasks,
    required this.actions,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final done = tasks.where((t) => t.isDone).length;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                avatar,
                const SizedBox(width: 10),
                Expanded(child: Text(title, style: text.title)),
                if (badge != null)
                  Text(badge!, style: text.caption.copyWith(color: palette.accent, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
              ],
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Row(
                children: [
                  Expanded(child: ProgressBar(value: tasks.isEmpty ? 0 : done / tasks.length, height: 6)),
                  const SizedBox(width: 10),
                  Text('진행 ${tasks.length - done} · 완료 $done', style: text.caption),
                ],
              ),
            ),
            if (tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('배정된 업무가 없어요', style: text.caption),
              ),
            for (final t in tasks) actions.row(t, withProject: true),
          ],
        ),
      ),
    );
  }
}
