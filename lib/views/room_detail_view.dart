import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import '../utils/confirm_dialog.dart';
import '../widgets/common/app_page.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/section_header.dart';
import '../widgets/reorder_handle.dart';
import '../widgets/room_detail_header.dart';
import '../widgets/task_detail_card.dart';
import 'form_routes.dart';

/// 텔레그램 업무방 상세 화면: 요약 카드, 체크리스트(꾹 눌러 순서 변경), 세부 항목/메모
class RoomDetailView extends StatelessWidget {
  final String roomId;

  const RoomDetailView({super.key, required this.roomId});

  Future<void> _deleteRoom(BuildContext context, String name) async {
    final confirmed = await confirmDelete(
      context,
      '"$name" 방을 삭제하면 방에 속한 할 일도 함께 삭제돼요.',
    );
    if (!context.mounted || !confirmed) return;
    context.read<RoomProvider>().deleteRoom(roomId);
    Navigator.pop(context);
  }

  Future<void> _deleteTask(BuildContext context, String id, String title) async {
    final confirmed = await confirmDelete(context, '"$title" 항목을 삭제할까요?');
    if (!context.mounted || !confirmed) return;
    context.read<RoomProvider>().deleteTask(id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final provider = context.watch<RoomProvider>();
    final room = provider.roomById(roomId);
    if (room == null) {
      return const Scaffold(
        body: EmptyState(icon: Icons.delete_outline, title: '삭제된 방이에요'),
      );
    }

    final allTasks = provider.tasksForRoom(roomId);
    final activeTasks = provider.activeTasksForRoom(roomId);

    return AppPage(
      title: room.name,
      actions: [
        IconButton(
          onPressed: () => openEditRoom(context, room),
          tooltip: '업무방 수정',
          icon: Icon(Icons.edit_rounded, color: palette.bodyText),
        ),
        IconButton(
          onPressed: () => _deleteRoom(context, room.name),
          tooltip: '방 삭제',
          icon: Icon(Icons.delete_outline_rounded, color: palette.danger),
        ),
      ],
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openAddTask(context, roomId),
        backgroundColor: palette.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('할 일 추가', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      slivers: [
        paddedSliver(top: 8, [
          RoomDetailHeader(
            room: room,
            totalCount: allTasks.length,
            doneCount: allTasks.length - activeTasks.length,
          ),
          const SizedBox(height: 32),
          SectionHeader(title: '체크리스트', count: activeTasks.length),
          if (activeTasks.isEmpty)
            const EmptyState(
              icon: Icons.task_alt_rounded,
              title: '완료하지 않은 할 일이 없어요',
              message: '아래 버튼으로 새 할 일을 추가해 보세요',
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
