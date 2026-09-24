import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import '../utils/confirm_dialog.dart';
import '../widgets/archived_task_tile.dart';
import '../widgets/page_number_tabs.dart';

const _pageSize = 10;

/// '완료된 일들' 아카이브 화면: 체크 완료한 항목을 따로 모아 보여준다
class ArchiveView extends StatefulWidget {
  const ArchiveView({super.key});

  @override
  State<ArchiveView> createState() => _ArchiveViewState();
}

class _ArchiveViewState extends State<ArchiveView> {
  int _page = 0;

  String _formatCompletedAt(DateTime? date) {
    if (date == null) return '';
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final h = date.hour.toString().padLeft(2, '0');
    final min = date.minute.toString().padLeft(2, '0');
    return '$m/$d $h:$min 완료';
  }

  Future<void> _deletePermanently(String taskId, String title) async {
    final confirmed = await confirmDelete(context, '"$title" 항목을 영구 삭제할까요?');
    if (!mounted || !confirmed) return;
    context.read<RoomProvider>().deleteTask(taskId);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final provider = context.watch<RoomProvider>();
    final archived = provider.archivedTasks;
    final totalPages = (archived.length / _pageSize).ceil();
    final page =
        _page >= totalPages ? (totalPages - 1).clamp(0, 1 << 30) : _page;
    final pageItems = archived.skip(page * _pageSize).take(_pageSize).toList();

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: palette.titleText,
                  ),
                ),
                Text(
                  '완료된 일들',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: palette.titleText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (pageItems.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 60),
                child: Center(
                  child: Text(
                    '아직 완료한 일이 없어요',
                    style: TextStyle(color: palette.subText),
                  ),
                ),
              )
            else
              ...pageItems.map(
                (task) => ArchivedTaskTile(
                  title: task.title,
                  roomName: provider.roomById(task.roomId ?? '')?.name,
                  completedLabel: _formatCompletedAt(task.completedAt),
                  onRestore: () =>
                      context.read<RoomProvider>().toggleTask(task.id),
                  onDelete: () => _deletePermanently(task.id, task.title),
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
