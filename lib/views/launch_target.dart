import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../providers/routine_provider.dart';
import '../services/launch_link.dart';
import '../services/sync_service.dart';
import '../services/telegram_nag.dart';
import '../utils/maybe_provider.dart';
import 'archive_view.dart';
import 'room_detail_view.dart';
import 'today_tasks_view.dart';

/// 텔레그램 알림의 [앱에서 보기]로 들어왔으면 해당 항목 화면을 열고, 그 알림의 끈질긴 알림을 끈다.
/// 이 기기에 아직 없으면(처음 로그인한 기기 등) 첫 동기화를 잠시 기다렸다가 다시 찾고,
/// 그래도 없으면(삭제된 항목) 안내만 띄운다.
Future<void> openLaunchTarget(BuildContext context) async {
  final ack = takeLaunchAck();
  if (ack != null) maybeProvider<TelegramNag>(context, listen: false)?.acknowledge(ack);
  final target = takeLaunchTarget();
  if (target == null) return;
  var page = _pageFor(context, target);
  final sync = maybeProvider<SyncService>(context, listen: false);
  if (page == null && sync != null) {
    try {
      await sync.firstSync.timeout(const Duration(seconds: 10));
    } catch (_) {
      // 서버에 닿지 않으면 이 기기 데이터로만 판단한다
    }
    if (!context.mounted) return;
    page = _pageFor(context, target);
  }
  if (page == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('알림의 항목을 찾을 수 없어요. 이미 삭제된 항목이에요.'),
      ),
    );
    return;
  }
  final found = page;
  Navigator.push(context, MaterialPageRoute(builder: (_) => found));
}

Widget? _pageFor(BuildContext context, LaunchTarget target) {
  final rooms = context.read<RoomProvider>();
  switch (target.kind) {
    case 'task':
      final task = rooms.taskById(target.id);
      if (task == null) return null;
      if (task.isDone) return const ArchiveView();
      final roomId = task.roomId;
      if (roomId != null && rooms.roomById(roomId) != null) {
        return RoomDetailView(roomId: roomId, focusTaskId: task.id);
      }
      return TodayTasksView(focusTaskId: task.id);
    case 'room':
      return rooms.roomById(target.id) == null
          ? null
          : RoomDetailView(roomId: target.id);
    case 'routine':
      return context.read<RoutineProvider>().routineById(target.id) == null
          ? null
          : const TodayTasksView(initialTab: 1);
  }
  return null;
}
