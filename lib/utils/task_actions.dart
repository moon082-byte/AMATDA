import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';

/// 할 일의 완료 상태를 바꾼다. 완료로 바뀌면 '실행 취소' 알림을 띄워
/// 실수로 체크했을 때 바로 원래 자리로 되돌릴 수 있게 한다.
void toggleTaskWithUndo(BuildContext context, TaskItem task) {
  final provider = context.read<RoomProvider>();
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

/// 완료된 할 일을 진행 중 목록으로 되돌린다
void restoreTask(BuildContext context, TaskItem task) {
  context.read<RoomProvider>().toggleTask(task.id);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      content: Text('"${task.title}"을(를) 할 일 목록으로 되돌렸어요'),
      duration: const Duration(seconds: 3),
    ));
}
