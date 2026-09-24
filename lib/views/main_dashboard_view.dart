import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import '../widgets/calendar_card.dart';
import '../widgets/dashboard_banner.dart';
import '../widgets/day_agenda.dart';
import 'archive_view.dart';
import 'settings_view.dart';
import 'today_tasks_view.dart';

/// 앱 진입 시 보여주는 메인 화면: 인사말, 요약 타일, 캘린더, 선택한 날의 일정
class MainDashboardView extends StatefulWidget {
  const MainDashboardView({super.key});

  @override
  State<MainDashboardView> createState() => _MainDashboardViewState();
}

class _MainDashboardViewState extends State<MainDashboardView> {
  DateTime _selectedDay = dateOnly(DateTime.now());

  void _push(Widget page) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final provider = context.watch<RoomProvider>();
    final pending = provider.totalPendingCount;
    final markedDates = provider.tasks
        .where((t) => t.dueDate != null)
        .map((t) => t.dueDate!)
        .toList();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formatFullDate(DateTime.now()), style: text.label),
                        const SizedBox(height: 6),
                        Text.rich(
                          TextSpan(
                            children: pending == 0
                                ? const [TextSpan(text: '오늘 할 일을\n모두 끝냈어요 🎉')]
                                : [
                                    const TextSpan(text: '할 일 '),
                                    TextSpan(
                                      text: '$pending개',
                                      style: TextStyle(color: palette.accent),
                                    ),
                                    const TextSpan(text: '가\n남아 있어요'),
                                  ],
                          ),
                          style: text.h1,
                        ),
                      ],
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _push(const SettingsView()),
                  tooltip: '설정',
                  style: IconButton.styleFrom(backgroundColor: palette.card),
                  icon: Icon(Icons.settings_rounded, color: palette.subText),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: DashboardBanner(
                    title: '오늘 할일',
                    count: pending,
                    icon: Icons.checklist_rounded,
                    color: palette.accent,
                    softColor: palette.accentSoft,
                    onTap: () => _push(const TodayTasksView()),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DashboardBanner(
                    title: '완료된 일들',
                    count: provider.totalCompletedCount,
                    icon: Icons.task_alt_rounded,
                    color: palette.success,
                    softColor: palette.successSoft,
                    onTap: () => _push(const ArchiveView()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            CalendarCard(
              markedDates: markedDates,
              selectedDay: _selectedDay,
              onDaySelected: (day) =>
                  setState(() => _selectedDay = dateOnly(day)),
            ),
            const SizedBox(height: 28),
            DayAgenda(day: _selectedDay),
          ],
        ),
      ),
    );
  }
}
