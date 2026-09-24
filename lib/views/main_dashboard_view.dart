import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import '../widgets/calendar_card.dart';
import '../widgets/dashboard_banner.dart';
import 'archive_view.dart';
import 'settings_view.dart';
import 'today_tasks_view.dart';

/// 앱 진입 시 보여주는 메인 화면: 캘린더 + 오늘 할일/완료된 일들 배너
class MainDashboardView extends StatelessWidget {
  const MainDashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final provider = context.watch<RoomProvider>();
    final markedDates = provider.tasks
        .where((t) => t.dueDate != null)
        .map((t) => t.dueDate!)
        .toList();

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '아맞다',
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: palette.titleText,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsView()),
                  ),
                  icon: Icon(Icons.settings_outlined, color: palette.subText),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CalendarCard(markedDates: markedDates),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: DashboardBanner(
                    title: '오늘 할일',
                    countLabel: '${provider.totalPendingCount}개',
                    icon: Icons.checklist_rtl,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const TodayTasksView(),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DashboardBanner(
                    title: '완료된 일들',
                    countLabel: '${provider.totalCompletedCount}개',
                    icon: Icons.task_alt,
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ArchiveView()),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
