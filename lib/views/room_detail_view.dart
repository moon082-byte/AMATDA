import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import '../utils/confirm_dialog.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/page_header.dart';
import '../widgets/common/section_header.dart';
import '../widgets/page_number_tabs.dart';
import '../widgets/room_detail_header.dart';
import '../widgets/task_detail_card.dart';
import '../widgets/task_form_sheet.dart';

const _pageSize = 10;

/// 텔레그램 업무방 상세 화면: 요약 카드, 체크리스트, 하위 세부 항목/메모
class RoomDetailView extends StatefulWidget {
  final String roomId;

  const RoomDetailView({super.key, required this.roomId});

  @override
  State<RoomDetailView> createState() => _RoomDetailViewState();
}

class _RoomDetailViewState extends State<RoomDetailView> {
  int _page = 0;

  Future<void> _deleteRoom(String name) async {
    final confirmed =
        await confirmDelete(context, '"$name" 방을 삭제하면 방에 속한 할 일도 함께 삭제돼요.');
    if (!mounted || !confirmed) return;
    context.read<RoomProvider>().deleteRoom(widget.roomId);
    Navigator.pop(context);
  }

  Future<void> _deleteTask(String taskId, String title) async {
    final confirmed = await confirmDelete(context, '"$title" 항목을 삭제할까요?');
    if (!mounted || !confirmed) return;
    context.read<RoomProvider>().deleteTask(taskId);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final provider = context.watch<RoomProvider>();
    final room = provider.roomById(widget.roomId);
    if (room == null) {
      return const Scaffold(
        body: EmptyState(icon: Icons.delete_outline, title: '삭제된 방이에요'),
      );
    }

    final allTasks = provider.tasksForRoom(widget.roomId);
    final activeTasks = provider.activeTasksForRoom(widget.roomId);
    final totalPages = (activeTasks.length / _pageSize).ceil();
    final page = _page.clamp(0, totalPages == 0 ? 0 : totalPages - 1);
    final pageTasks =
        activeTasks.skip(page * _pageSize).take(_pageSize).toList();

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAddTaskSheet(context, widget.roomId),
        backgroundColor: palette.accent,
        foregroundColor: Colors.white,
        elevation: 2,
        shape: const StadiumBorder(),
        icon: const Icon(Icons.add_rounded),
        label: const Text('할 일 추가', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
          children: [
            PageHeader(
              title: room.name,
              actions: [
                IconButton(
                  onPressed: () => _deleteRoom(room.name),
                  tooltip: '방 삭제',
                  icon: Icon(Icons.delete_outline_rounded, color: palette.danger),
                ),
              ],
            ),
            const SizedBox(height: 20),
            RoomDetailHeader(
              room: room,
              totalCount: allTasks.length,
              doneCount: allTasks.length - activeTasks.length,
            ),
            const SizedBox(height: 32),
            SectionHeader(title: '체크리스트', count: activeTasks.length),
            if (pageTasks.isEmpty)
              const EmptyState(
                icon: Icons.task_alt_rounded,
                title: '완료하지 않은 할 일이 없어요',
                message: '아래 버튼으로 새 할 일을 추가해 보세요',
              )
            else
              ...pageTasks.map(
                (task) => TaskDetailCard(
                  key: ValueKey(task.id),
                  task: task,
                  onEdit: () => showEditTaskSheet(context, task),
                  onDelete: () => _deleteTask(task.id, task.title),
                ),
              ),
            PageNumberTabs(
              pageCount: totalPages,
              currentPage: page,
              onPageSelected: (index) => setState(() => _page = index),
            ),
          ],
        ),
      ),
    );
  }
}
