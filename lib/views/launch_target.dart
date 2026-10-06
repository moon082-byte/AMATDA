import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../providers/routine_provider.dart';
import '../services/launch_link.dart';
import 'archive_view.dart';
import 'room_detail_view.dart';
import 'today_tasks_view.dart';

/// 텔레그램 알림의 [앱에서 보기]로 들어왔으면 해당 항목 화면을 연다.
/// 항목이 없으면(삭제됐거나 다른 기기·브라우저의 데이터) 안내만 띄운다.
void openLaunchTarget(BuildContext context) {
  final target = takeLaunchTarget();
  if (target == null) return;
  final page = _pageFor(context, target);
  if (page == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('알림의 항목을 찾을 수 없어요. 삭제됐거나 다른 브라우저에서 만든 항목이에요.'),
      ),
    );
    return;
  }
  Navigator.push(context, MaterialPageRoute(builder: (_) => page));
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
      return const TodayTasksView();
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
