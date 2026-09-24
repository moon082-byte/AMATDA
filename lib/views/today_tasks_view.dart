import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import '../utils/confirm_dialog.dart';
import '../widgets/create_room_sheet.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/page_number_tabs.dart';
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

  Future<void> _deleteRoom(BuildContext context, String roomId, String name) async {
    final confirmed = await confirmDelete(context, '"$name" 방을 삭제하면 방에 속한 할 일도 함께 삭제돼요.');
    if (!context.mounted || !confirmed) return;
    context.read<RoomProvider>().deleteRoom(roomId);
  }

  Future<void> _deleteTask(BuildContext context, String taskId, String title) async {
    final confirmed = await confirmDelete(context, '"$title" 항목을 삭제할까요?');
    if (!context.mounted || !confirmed) return;
    context.read<RoomProvider>().deleteTask(taskId);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final provider = context.watch<RoomProvider>();
    final activeTasks = provider.activeTasks;
    final totalPages = (activeTasks.length / _pageSize).ceil();
    final page = _page >= totalPages ? (totalPages - 1).clamp(0, 1 << 30) : _page;
    final pageTasks = activeTasks.skip(page * _pageSize).take(_pageSize).toList();

    return Scaffold(
      backgroundColor: palette.background,
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCreateRoomSheet(context),
        backgroundColor: palette.accent,
        tooltip: '새 업무방 추가',
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_ios_new, size: 18, color: palette.titleText),
                ),
                Text(
                  '오늘 할일',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: palette.titleText),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _sectionLabel('텔레그램 업무방', palette),
            const SizedBox(height: 12),
            SizedBox(
              height: 156,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: provider.rooms.length,
                itemBuilder: (context, index) {
                  final room = provider.rooms[index];
                  return TelegramRoomCard(
                    room: room,
                    pendingTaskCount: provider.pendingCountForRoom(room.id),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => RoomDetailView(roomId: room.id)),
                    ),
                    onLongPress: () => _deleteRoom(context, room.id, room.name),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
            _sectionLabel('할 일 목록', palette),
            const SizedBox(height: 12),
            if (pageTasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(
                  child: Text('완료하지 않은 할 일이 없어요', style: TextStyle(color: palette.subText)),
                ),
              )
            else
              ...pageTasks.map(
                (task) => TaskTile(
                  task: task,
                  roomName: provider.roomById(task.roomId ?? '')?.name,
                  onChanged: (_) => context.read<RoomProvider>().toggleTask(task.id),
                  onEdit: () => showEditTaskSheet(context, task),
                  onDelete: () => _deleteTask(context, task.id, task.title),
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

  Widget _sectionLabel(String text, AppPalette palette) {
    return Text(
      text,
      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: palette.subText),
    );
  }
}
