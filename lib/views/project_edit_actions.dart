import 'package:flutter/material.dart';
import '../models/project.dart';
import '../models/project_room.dart';
import '../services/project_service.dart';
import '../utils/confirm_dialog.dart';
import 'project_sheets.dart';

/// 팀장의 프로젝트·세부업무 추가·수정·삭제 흐름 (시트 → 서버 요청 → [apply]로 방 화면 갱신)
class ProjectEditActions {
  final BuildContext context;
  final ProjectService service;
  final Future<void> Function(Future<ProjectRoom> Function() request) apply;

  const ProjectEditActions({required this.context, required this.service, required this.apply});

  /// [p]가 없으면 새 프로젝트 추가
  Future<void> editProject(ProjectRoom room, [Project? p]) async {
    final input = await showProjectSheet(context, project: p);
    if (input == null) return;
    if (p == null) {
      return apply(() => service.addProject(room.id, name: input.name, dueAt: input.due));
    }
    if (!input.delete) {
      return apply(() => service.updateProject(p.id, name: input.name, dueAt: input.due));
    }
    if (!context.mounted) return;
    if (await confirmDelete(context, '"${p.name}" 프로젝트와 세부업무를 모두 삭제할까요?')) {
      await apply(() => service.deleteProject(p.id));
    }
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
    if (!context.mounted) return;
    if (await confirmDelete(context, '"${t.title}" 업무를 삭제할까요? 담당자에게 알림이 가요.')) {
      await apply(() => service.deleteTask(t.id));
    }
  }
}
