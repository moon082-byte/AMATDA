import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/project_room.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'calendar_card.dart';
import 'common/empty_state.dart';
import 'common/section_header.dart';
import 'project_card.dart';
import 'project_members_tab.dart';
import 'project_task_row.dart';
import 'segment_tabs.dart';

/// 방 화면 본문: 달력(마감 있는 날 표시) + 고른 날의 일정, [프로젝트][팀원] 탭
class ProjectRoomBody extends StatefulWidget {
  final ProjectRoom room;
  final TaskRowActions actions;
  final void Function(Project p) onEditProject;
  final void Function(Project p) onDeleteProject;
  final void Function(Project p) onAddTask;
  final void Function(String userId) onInvite;
  final void Function(ProjectMember m) onRemoveMember;

  const ProjectRoomBody({
    super.key,
    required this.room,
    required this.actions,
    required this.onEditProject,
    required this.onDeleteProject,
    required this.onAddTask,
    required this.onInvite,
    required this.onRemoveMember,
  });

  @override
  State<ProjectRoomBody> createState() => _ProjectRoomBodyState();
}

class _ProjectRoomBodyState extends State<ProjectRoomBody> {
  DateTime _day = dateOnly(DateTime.now());

  /// 0: 프로젝트, 1: 팀원
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final room = widget.room;
    final dated = [for (final t in room.allTasks) if (t.dueAt != null) t];
    final dayTasks = [for (final t in dated) if (isSameDate(t.dueAt!, _day)) t]
      ..sort((a, b) => a.isDone == b.isDone ? a.dueAt!.compareTo(b.dueAt!) : (a.isDone ? 1 : -1));
    final isToday = isSameDate(_day, DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CalendarCard(
          markedDates: [for (final t in dated) if (!t.isDone) t.dueAt!],
          selectedDay: _day,
          onDaySelected: (d) => setState(() => _day = dateOnly(d)),
        ),
        const SizedBox(height: 20),
        SectionHeader(title: isToday ? '오늘의 일정' : '${formatDateWithWeekday(_day)} 일정', count: dayTasks.length),
        if (dayTasks.isEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text('이 날 마감인 업무가 없어요', style: text.caption),
          ),
        for (final t in dayTasks) widget.actions.row(t, withProject: true),
        const SizedBox(height: 24),
        SegmentTabs(
          labels: ['프로젝트 ${room.projects.length}', '팀원 ${room.activeMembers.length}'],
          colors: [palette.accent, palette.routine],
          index: _tab,
          onChanged: (i) => setState(() => _tab = i),
        ),
        const SizedBox(height: 16),
        if (_tab == 1)
          ProjectMembersTab(
            room: room,
            actions: widget.actions,
            onInvite: widget.onInvite,
            onRemove: widget.onRemoveMember,
          )
        else if (room.projects.isEmpty)
          EmptyState(
            icon: Icons.folder_open_rounded,
            title: '아직 프로젝트가 없어요',
            message: room.isLeader ? '[프로젝트 추가]로 시작해 보세요' : '팀장이 프로젝트를 만들면 여기에 보여요',
          )
        else
          for (final p in room.projects)
            ProjectCard(
              key: ValueKey(p.id),
              project: p,
              room: room,
              actions: widget.actions,
              onAddTask: () => widget.onAddTask(p),
              onEdit: () => widget.onEditProject(p),
              onDelete: () => widget.onDeleteProject(p),
            ),
      ],
    );
  }
}
