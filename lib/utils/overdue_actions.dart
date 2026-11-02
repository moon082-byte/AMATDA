import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import '../services/sync_service.dart';
import 'confirm_action.dart';
import 'maybe_provider.dart';
import 'pick_date_time.dart';
import 'task_actions.dart';

/// [기한 변경]: 새 마감 일시를 고르면 할 일 목록으로 돌아간다 (알림 설정은 그대로)
Future<void> changeOverdueDue(BuildContext context, TaskItem task) async {
  if (task.isProjectTask) return _toast(context, '프로젝트 업무의 마감은 팀장만 바꿀 수 있어요');
  final picked = await pickDateTime(context);
  if (picked == null || !context.mounted) return;
  final next = task.copyWithEdits(title: task.title, dueDate: picked, remindAt: task.remindAt);
  if (next.isOverdueAt(DateTime.now())) {
    return _toast(context, '지금 이후의 마감 일시를 골라 주세요');
  }
  context.read<RoomProvider>().updateTask(next);
  _toast(context, '"${task.title}"을(를) 할 일 목록으로 옮겼어요');
}

/// [미완료 처리]: 목록에서는 빠지지만 완료와 구분해 '미완료'로 남긴다.
/// 프로젝트 업무는 동기화되면 서버가 프로젝트에도 미완료로 기록하고 팀장에게 알린다.
Future<void> markOverdueMissed(BuildContext context, TaskItem task) async {
  final ok = await confirmAction(
    context,
    title: '미완료로 처리할까요?',
    message: task.isProjectTask
        ? '${task.project!.roomName}방 - ${task.title}\n팀장에게 미완료로 알려요'
        : '"${task.title}"은(는) [완료된 일들]에 미완료로 남아요',
    confirmLabel: '미완료 처리',
  );
  if (!ok || !context.mounted) return;
  final provider = context.read<RoomProvider>();
  provider.updateTask(task.markMissed(true));
  if (task.isProjectTask) {
    maybeProvider<SyncService>(context, listen: false)?.syncNow();
    return _toast(context, '"${task.title}"을(를) 미완료 처리했어요');
  }
  showUndoSnackBar(context, '"${task.title}"을(를) 미완료 처리했어요', () {
    final current = provider.taskById(task.id);
    if (current != null && current.isMissed) provider.updateTask(current.markMissed(false));
  });
}

void _toast(BuildContext context, String message) => ScaffoldMessenger.of(context)
  ..hideCurrentSnackBar()
  ..showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 3)));
