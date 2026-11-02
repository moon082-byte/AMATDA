import 'dart:async';

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
import 'overdue_task_slivers.dart';
import 'routine_slivers.dart';
import 'today_task_slivers.dart';

/// '오늘 할일' 화면. [오늘 할일][기한 지남][루틴] 탭으로 나뉘고,
/// 오른쪽 아래 추가 버튼으로 할 일이나 루틴을 추가한다.
class TodayTasksView extends StatefulWidget {
  static const tasksTab = 0;
  static const overdueTab = 1;
  static const routineTab = 2;

  /// [tasksTab], [overdueTab], [routineTab] 중 하나
  final int initialTab;

  /// 펼친 채로 보여줄 할 일 (메인 화면 일정·알림에서 들어온 경우). 기한이 지났으면 [기한 지남] 탭에서 보여준다.
  final String? focusTaskId;

  const TodayTasksView({super.key, this.initialTab = tasksTab, this.focusTaskId});

  @override
  State<TodayTasksView> createState() => _TodayTasksViewState();
}

class _TodayTasksViewState extends State<TodayTasksView> {
  late int _tab = widget.initialTab;

  /// 화면을 보고 있는 동안 마감이 지난 할 일이 [기한 지남]으로 넘어가도록 주기적으로 다시 그린다
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 30), (_) => setState(() {}));
    final focus = widget.focusTaskId;
    final task = focus == null ? null : context.read<RoomProvider>().taskById(focus);
    if (task != null && task.isOverdueAt(DateTime.now())) _tab = TodayTasksView.overdueTab;
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  String _subtitle(BuildContext context, int overdue) {
    if (_tab == TodayTasksView.tasksTab) {
      final count = context.watch<RoomProvider>().activeTasks.length;
      return count == 0 ? '진행 중인 할 일이 없어요' : '진행 중인 할 일 $count개';
    }
    if (_tab == TodayTasksView.overdueTab) {
      return overdue == 0 ? '기한 지난 할 일이 없어요' : '기한 지난 할 일 $overdue개';
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
    final overdue = context.watch<RoomProvider>().overdueTasks.length;

    return AppPage(
      title: const ['오늘 할일', '기한 지남', '루틴'][_tab],
      subtitle: _subtitle(context, overdue),
      floatingActionButton: AddMenuFab(
        onAddTask: () {
          setState(() => _tab = TodayTasksView.tasksTab);
          openAddTask(context);
        },
        onAddRoutine: () {
          setState(() => _tab = TodayTasksView.routineTab);
          openAddRoutine(context);
        },
      ),
      slivers: [
        paddedSliver(top: 12, [
          SegmentTabs(
            labels: const ['오늘 할일', '기한 지남', '루틴'],
            colors: [palette.accent, palette.danger, palette.routine],
            badges: [0, overdue, 0],
            index: _tab,
            onChanged: (i) => setState(() => _tab = i),
          ),
          const SizedBox(height: 24),
        ]),
        switch (_tab) {
          TodayTasksView.tasksTab => TodayTaskSlivers(focusTaskId: widget.focusTaskId),
          TodayTasksView.overdueTab => OverdueTaskSlivers(focusTaskId: widget.focusTaskId),
          _ => const RoutineSlivers(),
        },
      ],
    );
  }
}
