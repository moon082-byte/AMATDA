import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/project.dart';
import '../models/project_room.dart';
import 'project_task_row.dart';
import 'slidable_actions.dart';

/// 방 화면 어디서나(프로젝트 탭·오늘의 일정·팀원 탭) 같은 업무 줄을 만들기 위한 동작 묶음.
/// 상태 버튼: 담당자 [완료](진행중)·[검토중](취소 가능), 팀장 [검토](최종완료·반려).
/// 팀장은 이름을 눌러 바로 고치고, 줄을 밀어 [수정](담당자·마감)[삭제], ✕로도 삭제한다.
class TaskRowActions {
  final ProjectRoom room;

  /// 상태 버튼을 눌렀을 때 (보고·검토 취소·최종완료/반려를 상태와 역할에 맞게)
  final void Function(ProjectTask) status;
  final void Function(ProjectTask) remind;
  final void Function(ProjectTask) edit;
  final void Function(ProjectTask, String title) rename;
  final void Function(ProjectTask) delete;
  final int Function(ProjectTask) reminderCount;

  const TaskRowActions({
    required this.room,
    required this.status,
    required this.remind,
    required this.edit,
    required this.rename,
    required this.delete,
    required this.reminderCount,
  });

  /// 상태 버튼 (없으면 null): (글자, 채운 버튼인지, 누를 수 있는지)
  ({String label, bool filled, bool enabled})? _button(ProjectTask t) {
    if (room.invited) return null;
    final mine = t.assigneeId == room.myId;
    return switch (t.status) {
      TaskStatus.open when mine => (label: '완료', filled: true, enabled: true),
      TaskStatus.review when mine => (label: '검토중', filled: false, enabled: true),
      TaskStatus.review when room.isLeader => (label: '검토', filled: true, enabled: true),
      TaskStatus.review => (label: '검토중', filled: false, enabled: false),
      _ => null,
    };
  }

  /// [t] 한 줄. [withProject]면 프로젝트 이름도, [compact]면 제목·버튼만 (오늘의 일정).
  Widget row(ProjectTask t, {bool withProject = false, bool compact = false}) {
    final mineOpen = t.assigneeId == room.myId && !t.isDone && !room.invited;
    final button = _button(t);
    final leader = room.isLeader;
    final child = ProjectTaskRow(
      task: t,
      assignee: room.memberById(t.assigneeId)?.handle ?? '담당자 없음',
      projectName: withProject ? room.projectOf(t).name : null,
      mine: t.assigneeId == room.myId,
      compact: compact,
      statusLabel: button?.label,
      statusFilled: button?.filled ?? true,
      onStatus: button?.enabled ?? false ? () => status(t) : null,
      onReminder: mineOpen ? () => remind(t) : null,
      reminderCount: reminderCount(t),
      onRename: leader && !t.isDone ? (title) => rename(t, title) : null,
      onDelete: leader ? () => delete(t) : null,
    );
    return Builder(
      key: ValueKey(t.id),
      builder: (context) => Slidable(
        enabled: leader,
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.44,
          children: buildEditDeleteActions(context,
              onEdit: () => edit(t), onDelete: () => delete(t)),
        ),
        child: child,
      ),
    );
  }
}
