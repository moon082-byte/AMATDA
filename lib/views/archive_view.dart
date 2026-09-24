import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../theme/app_typography.dart';
import '../utils/confirm_dialog.dart';
import '../utils/date_format.dart';
import '../widgets/archived_task_tile.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/page_header.dart';
import '../widgets/page_number_tabs.dart';

const _pageSize = 10;

/// '완료된 일들' 아카이브 화면: 완료한 항목을 완료한 날짜별로 묶어 보여준다
class ArchiveView extends StatefulWidget {
  const ArchiveView({super.key});

  @override
  State<ArchiveView> createState() => _ArchiveViewState();
}

class _ArchiveViewState extends State<ArchiveView> {
  int _page = 0;

  Future<void> _deletePermanently(String taskId, String title) async {
    final confirmed = await confirmDelete(context, '"$title" 항목을 영구 삭제할까요?');
    if (!mounted || !confirmed) return;
    context.read<RoomProvider>().deleteTask(taskId);
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final provider = context.watch<RoomProvider>();
    final archived = provider.archivedTasks;
    final totalPages = (archived.length / _pageSize).ceil();
    final page = _page.clamp(0, totalPages == 0 ? 0 : totalPages - 1);
    final pageItems = archived.skip(page * _pageSize).take(_pageSize).toList();

    // 완료 날짜가 바뀌는 지점마다 날짜 제목을 끼워 넣는다
    final children = <Widget>[];
    String? lastGroup;
    for (final task in pageItems) {
      final doneAt = task.completedAt ?? task.createdAt;
      final group = formatDayGroup(doneAt);
      if (group != lastGroup) {
        children.add(Padding(
          padding: EdgeInsets.fromLTRB(4, lastGroup == null ? 0 : 14, 0, 10),
          child: Text(group, style: text.label),
        ));
        lastGroup = group;
      }
      children.add(ArchivedTaskTile(
        title: task.title,
        roomName: provider.roomById(task.roomId ?? '')?.name,
        completedLabel: '${formatTime(doneAt)} 완료',
        onRestore: () => provider.toggleTask(task.id),
        onDelete: () => _deletePermanently(task.id, task.title),
      ));
    }

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            PageHeader(
              title: '완료된 일들',
              subtitle: archived.isEmpty
                  ? '완료한 일이 여기에 모여요'
                  : '지금까지 ${archived.length}개를 완료했어요',
            ),
            const SizedBox(height: 28),
            if (pageItems.isEmpty)
              const EmptyState(
                icon: Icons.inventory_2_outlined,
                title: '아직 완료한 일이 없어요',
                message: '할 일을 체크하면 이곳에 기록돼요',
              )
            else
              ...children,
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
