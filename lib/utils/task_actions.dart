import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';

/// 할 일의 완료 상태를 바꾼다. 완료로 바뀌면 '실행 취소' 알림을 띄워
/// 실수로 체크했을 때 바로 원래 자리로 되돌릴 수 있게 한다.
void toggleTaskWithUndo(BuildContext context, TaskItem task) {
  final provider = context.read<RoomProvider>();
  final messenger = ScaffoldMessenger.of(context);
  provider.toggleTask(task.id);
  messenger.hideCurrentSnackBar();
  if (task.isDone) return;

  messenger.showSnackBar(SnackBar(
    content: Text('"${task.title}" 완료했어요'),
    duration: const Duration(seconds: 4),
    action: SnackBarAction(
      label: '실행 취소',
      onPressed: () {
        final current = provider.taskById(task.id);
        if (current != null && current.isDone) provider.toggleTask(task.id);
      },
    ),
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
