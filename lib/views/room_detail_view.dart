import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../providers/routine_provider.dart';
import '../theme/app_palette.dart';
import '../utils/nearest_due.dart';
import '../utils/room_actions.dart';
import '../widgets/add_menu_fab.dart';
import '../widgets/common/app_page.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/room_detail_header.dart';
import '../widgets/segment_tabs.dart';
import 'form_routes.dart';
import 'room_task_slivers.dart';
import 'routine_slivers.dart';

/// 텔레그램 업무방 상세 화면: 요약 카드 + [할일][루틴] 탭.
/// 할일 탭은 체크리스트(꾹 눌러 순서 변경)·세부 항목/메모,
/// 루틴 탭은 이 방에 연결된 루틴(오늘 할 루틴은 탭해서 완료 체크).
class RoomDetailView extends StatefulWidget {
  final String roomId;

  /// 처음부터 펼쳐서 보여줄 할 일 (텔레그램 알림의 [앱에서 보기]로 들어온 경우)
  final String? focusTaskId;

  const RoomDetailView({super.key, required this.roomId, this.focusTaskId});

  @override
  State<RoomDetailView> createState() => _RoomDetailViewState();
}

class _RoomDetailViewState extends State<RoomDetailView> {
  /// 0: 할일, 1: 루틴
  int _tab = 0;

  String get _roomId => widget.roomId;

  Future<void> _deleteRoom(String name) async {
    final deleted = await confirmDeleteRoom(context, _roomId, name);
    if (deleted && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final provider = context.watch<RoomProvider>();
    final room = provider.roomById(_roomId);
    if (room == null) {
      return const Scaffold(
        body: EmptyState(icon: Icons.delete_outline, title: '삭제된 방이에요'),
      );
    }

    final activeTasks = provider.activeTasksForRoom(_roomId);
    final routineCount =
        context.watch<RoutineProvider>().routinesForRoom(_roomId).length;

    return AppPage(
      title: room.name,
      actions: [
        IconButton(
          onPressed: () => openEditRoom(context, room),
          tooltip: '업무방 수정',
          icon: Icon(Icons.edit_rounded, color: palette.bodyText),
        ),
        IconButton(
          onPressed: () => _deleteRoom(room.name),
          tooltip: '방 삭제',
          icon: Icon(Icons.delete_outline_rounded, color: palette.danger),
        ),
      ],
      floatingActionButton: AddMenuFab(
        onAddTask: () {
          setState(() => _tab = 0);
          openAddTask(context, _roomId);
        },
        onAddRoutine: () {
          setState(() => _tab = 1);
          openAddRoutine(context, _roomId);
        },
      ),
      slivers: [
        paddedSliver(top: 8, [
          RoomDetailHeader(
            room: room,
            nearestTask: nearestDueTask(activeTasks),
          ),
          const SizedBox(height: 24),
          SegmentTabs(
            labels: ['할일 ${activeTasks.length}', '루틴 $routineCount'],
            colors: [palette.accent, palette.routine],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 24),
        ]),
        _tab == 0
            ? RoomTaskSlivers(roomId: _roomId, focusTaskId: widget.focusTaskId)
            : RoutineSlivers(roomId: _roomId),
      ],
    );
  }
}
