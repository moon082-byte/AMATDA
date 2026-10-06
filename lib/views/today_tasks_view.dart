import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/room_provider.dart';
import '../providers/routine_provider.dart';
import '../theme/app_palette.dart';
import '../utils/date_format.dart';
import '../widgets/add_menu_fab.dart';
import '../widgets/common/app_page.dart';
import '../widgets/segment_tabs.dart';
import 'form_routes.dart';
import 'routine_slivers.dart';
import 'today_task_slivers.dart';

/// '오늘 할일' 화면. [오늘 할일][루틴] 탭으로 나뉘고,
/// 오른쪽 아래 추가 버튼으로 할 일이나 루틴을 추가한다.
class TodayTasksView extends StatefulWidget {
  /// 0: 오늘 할일, 1: 루틴
  final int initialTab;

  const TodayTasksView({super.key, this.initialTab = 0});

  @override
  State<TodayTasksView> createState() => _TodayTasksViewState();
}

class _TodayTasksViewState extends State<TodayTasksView> {
  late int _tab = widget.initialTab;

  String _subtitle(BuildContext context) {
    if (_tab == 0) {
      final count = context.watch<RoomProvider>().activeTasks.length;
      return count == 0 ? '진행 중인 할 일이 없어요' : '진행 중인 할 일 $count개';
    }
    final today = dateOnly(DateTime.now());
    final routines = context.watch<RoutineProvider>().routinesOn(today);
    if (routines.isEmpty) return '오늘은 할 루틴이 없어요';
    final done = routines.where((r) => r.isDoneOn(today)).length;
    return '오늘 루틴 ${routines.length}개 중 $done개 완료';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return AppPage(
      title: _tab == 0 ? '오늘 할일' : '루틴',
      subtitle: _subtitle(context),
      floatingActionButton: AddMenuFab(
        onAddTask: () {
          setState(() => _tab = 0);
          openAddTask(context);
        },
        onAddRoutine: () {
          setState(() => _tab = 1);
          openAddRoutine(context);
        },
      ),
      slivers: [
        paddedSliver(top: 12, [
          SegmentTabs(
            labels: const ['오늘 할일', '루틴'],
            colors: [palette.accent, palette.routine],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 24),
        ]),
        _tab == 0 ? const TodayTaskSlivers() : const RoutineSlivers(),
      ],
    );
  }
}
