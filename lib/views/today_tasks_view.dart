import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../utils/confirm_dialog.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/page_header.dart';
import '../widgets/common/section_header.dart';
import '../widgets/create_room_sheet.dart';
import '../widgets/page_number_tabs.dart';
import '../widgets/task_form_sheet.dart';
import '../widgets/task_tile.dart';
import '../widgets/telegram_room_card.dart';
import 'room_detail_view.dart';

const _pageSize = 10;

/// '오늘 할일' 화면: 텔레그램 업무방 캐러셀 + 진행 중인 체크리스트 (10개씩 페이지 노출)
class TodayTasksView extends StatefulWidget {
  const TodayTasksView({super.key});

  @override
  State<TodayTasksView> createState() => _TodayTasksViewState();
}

class _TodayTasksViewState extends State<TodayTasksView> {
  int _page = 0;

  Future<void> _deleteRoom(String roomId, String name) async {
    final confirmed = await confirmDelete(
      context,
      '"$name" 방을 삭제하면 방에 속한 할 일도 함께 삭제돼요.',
    );
    if (!mounted || !confirmed) return;
    context.read<RoomProvider>().deleteRoom(roomId);
  }

  Future<void> _deleteTask(String taskId, String title) async {
    final confirmed = await confirmDelete(context, '"$title" 항목을 삭제할까요?');
    if (!mounted || !confirmed) return;
    context.read<RoomProvider>().deleteTask(taskId);
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoomProvider>();
    final activeTasks = provider.activeTasks;
    final rooms = provider.rooms;
    final totalPages = (activeTasks.length / _pageSize).ceil();
    final page = _page.clamp(0, totalPages == 0 ? 0 : totalPages - 1);
    final pageTasks = activeTasks
        .skip(page * _pageSize)
        .take(_pageSize)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            PageHeader(
              title: '오늘 할일',
              subtitle: activeTasks.isEmpty
                  ? '진행 중인 할 일이 없어요'
                  : '진행 중인 할 일 ${activeTasks.length}개',
            ),
            const SizedBox(height: 28),
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
                      return AddRoomCard(
                        onTap: () => showCreateRoomSheet(context),
                      );
                    }
                    final room = rooms[index];
                    return TelegramRoomCard(
                      room: room,
                      pendingTaskCount: provider.pendingCountForRoom(room.id),
                      totalTaskCount: provider.tasksForRoom(room.id).length,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => RoomDetailView(roomId: room.id),
                        ),
                      ),
                      onLongPress: () => _deleteRoom(room.id, room.name),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 32),
            const SectionHeader(title: '할 일 목록'),
            if (pageTasks.isEmpty)
              const EmptyState(
                icon: Icons.celebration_rounded,
                title: '완료하지 않은 할 일이 없어요',
                message: '업무방에서 새 할 일을 추가해 보세요',
              )
            else
              ...pageTasks.map(
                (task) => TaskTile(
                  task: task,
                  roomName: provider.roomById(task.roomId ?? '')?.name,
                  onChanged: (_) => provider.toggleTask(task.id),
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
