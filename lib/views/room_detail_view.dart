import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import '../utils/confirm_dialog.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/page_number_tabs.dart';
import '../widgets/room_detail_header.dart';
import '../widgets/room_detail_title_bar.dart';
import '../widgets/task_detail_card.dart';

const _pageSize = 10;

/// 텔레그램 업무방 상세 화면: 마감 D-Day, 체크리스트, 하위 세부 항목/메모
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
    if (mounted) Navigator.pop(context);
  }

  Future<void> _deleteTask(String taskId, String title) async {
    final confirmed = await confirmDelete(context, '"$title" 항목을 삭제할까요?');
    if (!mounted || !confirmed) return;
    context.read<RoomProvider>().deleteTask(taskId);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Consumer<RoomProvider>(
      builder: (context, provider, _) {
        final room = provider.roomById(widget.roomId);
        if (room == null) {
          return Scaffold(
            backgroundColor: palette.background,
            body: const Center(child: Text('삭제된 방이에요')),
          );
        }

        final activeTasks = provider.activeTasksForRoom(widget.roomId);
        final totalPages = (activeTasks.length / _pageSize).ceil();
        final page =
            _page >= totalPages ? (totalPages - 1).clamp(0, 1 << 30) : _page;
        final pageTasks =
            activeTasks.skip(page * _pageSize).take(_pageSize).toList();

        return Scaffold(
          backgroundColor: palette.background,
          body: SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 20, 40),
              children: [
                RoomDetailTitleBar(
                  name: room.name,
                  onDelete: () => _deleteRoom(room.name),
                ),
                const SizedBox(height: 12),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: RoomDetailHeader(room: room),
                ),
                const SizedBox(height: 28),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '체크리스트',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: palette.subText,
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => showAddTaskSheet(context, widget.roomId),
                        icon: Icon(Icons.add, size: 18, color: palette.accent),
                        label: Text(
                          '할 일 추가',
                          style: TextStyle(
                            color: palette.accent,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                if (pageTasks.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 40),
                    child: Center(
                      child: Text(
                        '완료하지 않은 할 일이 없어요',
                        style: TextStyle(color: palette.subText),
                      ),
                    ),
                  )
                else
                  ...pageTasks.map(
                    (task) => TaskDetailCard(
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
      },
    );
  }
}
