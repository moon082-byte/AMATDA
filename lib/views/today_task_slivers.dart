import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../utils/confirm_dialog.dart';
import '../utils/nearest_due.dart';
import '../widgets/common/app_page.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/section_header.dart';
import '../widgets/reorder_handle.dart';
import '../widgets/task_detail_card.dart';
import '../widgets/telegram_room_card.dart';
import 'room_detail_view.dart';
import 'form_routes.dart';

/// '오늘 할일' 탭: 텔레그램 업무방 캐러셀 + 진행 중인 할 일 전체 목록.
/// 할 일을 누르면 세부 항목이 펼쳐지고, 꾹 눌러 끌면 순서를 바꿀 수 있다.
class TodayTaskSlivers extends StatelessWidget {
  /// 펼친 채로 보여줄 할 일 (메인 화면 일정에서 들어온 경우)
  final String? focusTaskId;

  const TodayTaskSlivers({super.key, this.focusTaskId});

  Future<void> _deleteRoom(BuildContext context, String id, String name) async {
    final confirmed = await confirmDelete(
      context,
      '"$name" 방을 삭제하면 방에 속한 할 일도 함께 삭제돼요.',
    );
    if (!context.mounted || !confirmed) return;
    context.read<RoomProvider>().deleteRoom(id);
  }

  Future<void> _deleteTask(BuildContext context, String id, String title) async {
    final confirmed = await confirmDelete(context, '"$title" 항목을 삭제할까요?');
    if (!context.mounted || !confirmed) return;
    context.read<RoomProvider>().deleteTask(id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoomProvider>();
    final activeTasks = provider.activeTasks;
    final rooms = provider.rooms;

    return SliverMainAxisGroup(
      slivers: [
        paddedSliver([
          SectionHeader(title: '텔레그램 업무방', count: rooms.length),
          // 캐러셀은 화면 좌우 끝까지 이어지도록 목록 여백 밖으로 넓힌다
          SizedBox(
            height: 172,
            child: OverflowBox(
              maxWidth: MediaQuery.sizeOf(context).width,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                scrollDirection: Axis.horizontal,
                clipBehavior: Clip.none,
                itemCount: rooms.length + 1,
                itemBuilder: (context, index) {
                  if (index == rooms.length) {
                    return AddRoomCard(onTap: () => openCreateRoom(context));
                  }
                  final room = rooms[index];
                  return TelegramRoomCard(
                    room: room,
                    pendingTaskCount: provider.pendingCountForRoom(room.id),
                    nearestDue: nearestDueTask(
                            provider.activeTasksForRoom(room.id))
                        ?.dueDate,
                    totalTaskCount: provider.tasksForRoom(room.id).length,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RoomDetailView(roomId: room.id),
                      ),
                    ),
                    onLongPress: () => _deleteRoom(context, room.id, room.name),
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 32),
          SectionHeader(
            title: '할 일 목록',
            trailing: activeTasks.length > 1
                ? const _ReorderHint()
                : null,
          ),
          if (activeTasks.isEmpty)
            const EmptyState(
              icon: Icons.celebration_rounded,
              title: '완료하지 않은 할 일이 없어요',
              message: '아래 추가 버튼으로 새 할 일을 추가해 보세요',
            ),
        ]),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverReorderableList(
            itemCount: activeTasks.length,
            proxyDecorator: liftedProxy,
            onReorderItem: (from, to) => provider.reorderTasks(
              [for (final t in activeTasks) t.id],
              from,
              to,
            ),
            itemBuilder: (context, index) {
              final task = activeTasks[index];
              return TaskDetailCard(
                key: ValueKey(task.id),
                task: task,
                dragIndex: index,
                initiallyExpanded: task.id == focusTaskId,
                roomName: provider.roomById(task.roomId ?? '')?.name,
                onEdit: () => openEditTask(context, task),
                onDelete: () => _deleteTask(context, task.id, task.title),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// 목록 제목 오른쪽의 "꾹 눌러 순서 변경" 안내
class _ReorderHint extends StatelessWidget {
  const _ReorderHint();

  @override
  Widget build(BuildContext context) {
    return Text(
      '꾹 눌러서 순서 변경',
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).hintColor,
          ),
    );
  }
}
