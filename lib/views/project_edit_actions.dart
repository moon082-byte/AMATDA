import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/project_room.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../services/project_service.dart';
import '../services/sync_service.dart';
import '../utils/confirm_action.dart';
import '../utils/confirm_dialog.dart';
import '../utils/maybe_provider.dart';
import '../widgets/remind_at_popup.dart';
import 'project_sheets.dart';

/// 방 화면의 업무 동작 (시트·확인 창 → 서버 요청 → [apply]로 방 화면 갱신)
/// - 팀장: 프로젝트·세부업무 추가·수정·삭제(확인 창), 팀원 초대·내보내기
/// - 담당자: 내 업무 완료 보고, 리마인더(내 개인 할일에 연결된 할 일의 리마인더를 바꾼다)
class ProjectEditActions {
  final BuildContext context;
  final ProjectService service;
  final Future<void> Function(Future<ProjectRoom> Function() request) apply;

  const ProjectEditActions({required this.context, required this.service, required this.apply});

  /// 내 개인 할일에 들어온 연결 할 일 (서버가 배정할 때 넣고, 동기화로 받는다)
  static String mirrorId(ProjectTask t) => 'pt_${t.id}';

  void _syncSoon() => maybeProvider<SyncService>(context, listen: false)?.syncNow();

  /// 상태 버튼: 진행중 [완료] → 보고(팀장 본인 업무는 바로 최종완료),
  /// 내 업무 [검토중] → 검토 요청 취소, 팀장 [검토] → 최종완료·반려
  Future<void> status(ProjectRoom room, ProjectTask t) async {
    final mine = t.assigneeId == room.myId;
    Future<ProjectRoom> Function()? request;
    if (t.status == TaskStatus.open && mine) {
      final ok = room.isLeader
          ? await confirmAction(context, title: '최종완료 하시겠습니까?', message: '"${t.title}"', confirmLabel: '최종완료')
          : await confirmAction(context, title: '해당 업무 보고드리겠습니까?', message: '"${t.title}" 완료를 팀장에게 보고해요.', confirmLabel: '완료');
      if (ok) request = () => service.complete(t.id);
    } else if (t.status == TaskStatus.review && mine) {
      final ok = await confirmAction(context, title: '검토 요청을 취소하시겠습니까?', confirmLabel: '확인');
      if (ok) request = () => service.cancelReview(t.id);
    } else if (t.status == TaskStatus.review && room.isLeader) {
      final approve = await chooseReviewResult(context, t.title);
      if (approve != null) request = () => approve ? service.approve(t.id) : service.reject(t.id);
    }
    if (request == null) return;
    await apply(request);
    _syncSoon();
  }

  /// 팀장: 업무 이름만 그 자리에서 고친다 (담당자·마감은 그대로)
  Future<void> rename(ProjectTask t, String title) =>
      apply(() => service.updateTask(t.id, title: title, assigneeId: t.assigneeId, dueAt: t.dueAt));

  /// 내 업무의 리마인더 (개인 할일과 같은 날짜·시간 방식)
  Future<void> remind(ProjectTask task) async {
    final rooms = context.read<RoomProvider>();
    final mine = rooms.taskById(mirrorId(task));
    if (mine == null) {
      _syncSoon();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('개인 할일로 가져오는 중이에요. 잠시 후 다시 눌러 주세요')));
      return;
    }
    final picked = await showRemindAtPopup(context,
        initial: mine.remindAt, dueDate: mine.dueDate, title: '리마인더 · ${task.title}');
    if (picked == null) return;
    rooms.updateTask(mine.copyWithEdits(title: mine.title, dueDate: mine.dueDate, remindAt: picked));
  }

  /// [p]가 없으면 새 프로젝트 추가
  Future<void> editProject(ProjectRoom room, [Project? p]) async {
    final input = await showProjectSheet(context, project: p);
    if (input == null) return;
    if (p == null) {
      return apply(() => service.addProject(room.id,
          name: input.name, dueAt: input.due, remindAt: input.remindAt));
    }
    if (!input.delete) {
      return apply(() => service.updateProject(p.id,
          name: input.name, dueAt: input.due, remindAt: input.remindAt));
    }
    await deleteProject(p);
  }

  Future<void> deleteProject(Project p) async {
    if (!context.mounted) return;
    if (await confirmDelete(context, '"${p.name}" 프로젝트와 세부업무를 모두 삭제할까요?')) {
      await apply(() => service.deleteProject(p.id));
    }
  }

  Future<void> deleteTask(ProjectTask t) async {
    if (!context.mounted) return;
    if (await confirmDelete(context, '"${t.title}" 업무를 삭제할까요? 담당자에게 알림이 가요.')) {
      await apply(() => service.deleteTask(t.id));
    }
  }

  Future<void> invite(ProjectRoom room, String userId) =>
      apply(() => service.invite(room.id, userId));

  /// 팀원 내보내기 또는 초대 취소 (확인 창)
  Future<void> removeMember(ProjectRoom room, ProjectMember m) async {
    final ok = await confirmAction(
      context,
      title: m.invited ? '초대를 취소할까요?' : '${m.handle}님을 내보낼까요?',
      message: m.invited ? null : '맡고 있던 진행 중 업무는 담당자 없음으로 바뀌어요.',
      confirmLabel: m.invited ? '초대 취소' : '내보내기',
    );
    if (ok) await apply(() => service.removeMember(room.id, m.userId));
  }

  /// [t]가 없으면 [p]에 새 세부업무 추가. 담당자는 참여 중인 팀원 중에서 고른다.
  Future<void> editTask(ProjectRoom room, Project p, [ProjectTask? t]) async {
    final input = await showTaskSheet(context, task: t, members: room.activeMembers);
    if (input == null) return;
    if (t == null) {
      return apply(() => service.addTask(p.id,
          title: input.title, assigneeId: input.assigneeId, dueAt: input.due));
    }
    if (!input.delete) {
      return apply(() => service.updateTask(t.id,
          title: input.title, assigneeId: input.assigneeId, dueAt: input.due));
    }
    await deleteTask(t);
  }
}
