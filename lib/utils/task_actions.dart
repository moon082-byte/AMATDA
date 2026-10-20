import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import 'confirm_action.dart';

/// 할 일의 완료 상태를 바꾼다. 완료로 바뀌면 '실행 취소' 알림을 띄워
/// 실수로 체크했을 때 바로 원래 자리로 되돌릴 수 있게 한다.
/// 프로젝트에서 배정된 업무는 확인을 받고 완료 보고한다 (되돌릴 수 없음).
Future<void> toggleTaskWithUndo(BuildContext context, TaskItem task) async {
  final provider = context.read<RoomProvider>();
  final project = task.project;
  if (project != null) {
    if (task.isDone) return _toast(context, '프로젝트 업무는 완료를 되돌릴 수 없어요');
    final ok = await confirmAction(
      context,
      title: '${project.roomName}방 - ${task.title} 업무 완료입니까?',
      message: '확인하면 팀장에게 완료 보고가 가요.',
    );
    if (!ok || !context.mounted) return;
    provider.toggleTask(task.id); // 동기화되면 서버가 프로젝트에 완료를 반영하고 팀장에게 알린다
    return _toast(context, '"${task.title}" 완료를 보고했어요');
  }
  provider.toggleTask(task.id);
  if (task.isDone) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    return;
  }
  showUndoSnackBar(context, '"${task.title}" 완료했어요', () {
    final current = provider.taskById(task.id);
    if (current != null && current.isDone) provider.toggleTask(task.id);
  });
}

/// '실행 취소' 버튼이 달린 알림을 5초 동안 띄운다.
/// (버튼이 있는 SnackBar는 기본값이 '계속 표시'라서 persist: false로 자동으로 닫히게 한다)
void showUndoSnackBar(
  BuildContext context,
  String message,
  VoidCallback onUndo, {
  String undoLabel = '실행 취소',
}) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 5),
      persist: false,
      action: SnackBarAction(label: undoLabel, onPressed: onUndo),
    ));
}

void _toast(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));

/// 완료된 할 일을 진행 중 목록으로 되돌린다 (프로젝트 업무는 되돌릴 수 없다)
void restoreTask(BuildContext context, TaskItem task) {
  if (task.isProjectTask) return _toast(context, '프로젝트 업무는 완료를 되돌릴 수 없어요');
  context.read<RoomProvider>().toggleTask(task.id);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('"${task.title}"을(를) 할 일 목록으로 되돌렸어요'),
      duration: const Duration(seconds: 3),
    ));
}
