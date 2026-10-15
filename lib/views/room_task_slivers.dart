import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../utils/confirm_dialog.dart';
import '../widgets/common/app_page.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/section_header.dart';
import '../widgets/reorder_handle.dart';
import '../widgets/task_detail_card.dart';
import 'form_routes.dart';

/// 업무방 상세의 [할일] 탭: 체크리스트(꾹 눌러 순서 변경), 세부 항목/메모
class RoomTaskSlivers extends StatelessWidget {
  final String roomId;

  /// 처음부터 펼쳐서 보여줄 할 일
  final String? focusTaskId;

  const RoomTaskSlivers({super.key, required this.roomId, this.focusTaskId});

  Future<void> _deleteTask(BuildContext context, String id, String title) async {
    final confirmed = await confirmDelete(context, '"$title" 항목을 삭제할까요?');
    if (!context.mounted || !confirmed) return;
    context.read<RoomProvider>().deleteTask(id);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoomProvider>();
    final activeTasks = provider.activeTasksForRoom(roomId);

    return SliverMainAxisGroup(
      slivers: [
        paddedSliver([
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
                initiallyExpanded: task.id == focusTaskId,
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
