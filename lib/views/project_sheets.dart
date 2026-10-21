import 'package:flutter/material.dart';
import '../models/project.dart';
import '../widgets/project_edit_sheet.dart';

/// 팀장이 프로젝트·세부업무를 추가·수정하는 아래 시트들.
/// 저장하면 입력값을, [삭제]를 누르면 delete: true를, 닫으면 null을 돌려준다.
typedef TaskInput = ({String title, String? assigneeId, DateTime? due, bool delete});
typedef ProjectInput = ({String name, DateTime? due, List<DateTime> remindAt, bool delete});

Future<T?> _sheet<T>(BuildContext context, Widget child) => showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: SingleChildScrollView(child: child),
      ),
    );

Future<ProjectInput?> showProjectSheet(BuildContext context, {Project? project}) =>
    _sheet(context, ProjectEditSheet(
      title: project == null ? '프로젝트 추가' : '프로젝트 수정',
      label: '프로젝트 이름',
      initialName: project?.name ?? '',
      initialDue: project?.dueAt,
      initialRemindAt: project?.remindAt ?? const [],
      canDelete: project != null,
      build: (name, _, due, remindAt, delete) =>
          (name: name, due: due, remindAt: remindAt, delete: delete),
    ));

Future<TaskInput?> showTaskSheet(BuildContext context,
        {ProjectTask? task, required List<ProjectMember> members}) =>
    _sheet(context, ProjectEditSheet(
      title: task == null ? '세부업무 추가' : '세부업무 수정',
      label: '업무 이름',
      initialName: task?.title ?? '',
      initialDue: task?.dueAt,
      members: members,
      initialAssignee: task?.assigneeId,
      canDelete: task != null,
      build: (name, assignee, due, _, delete) =>
          (title: name, assigneeId: assignee, due: due, delete: delete),
    ));
