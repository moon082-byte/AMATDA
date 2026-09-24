import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'common/app_card.dart';

/// 메인 화면의 캘린더 카드. 마감일이 있는 날짜에 점을 찍고,
/// 날짜를 누르면 [onDaySelected]로 선택한 날을 알려준다.
class CalendarCard extends StatefulWidget {
  final List<DateTime> markedDates;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  const CalendarCard({
    super.key,
    required this.markedDates,
    required this.selectedDay,
    required this.onDaySelected,
  });

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard> {
  late DateTime _focusedDay = widget.selectedDay;

  List<Object> _eventsForDay(DateTime day) {
    final hasEvent = widget.markedDates.any((d) => isSameDate(d, day));
    return hasEvent ? const [1] : const [];
  }

  void _moveMonth(int delta) => setState(() {
        _focusedDay = DateTime(_focusedDay.year, _focusedDay.month + delta, 1);
      });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          _buildHeader(context),
          const SizedBox(height: 4),
          _buildCalendar(context),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final p = context.palette;
    final today = DateTime.now();
    final isCurrentMonth =
        _focusedDay.year == today.year && _focusedDay.month == today.month;

    return Row(
      children: [
        const SizedBox(width: 8),
        Text(
          formatYearMonth(_focusedDay),
          style: context.text.title.copyWith(fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        if (!isCurrentMonth)
          TextButton(
            onPressed: () {
              setState(() => _focusedDay = today);
              widget.onDaySelected(today);
            },
            child: const Text('오늘'),
          ),
        IconButton(
          onPressed: () => _moveMonth(-1),
          tooltip: '이전 달',
          icon: Icon(Icons.chevron_left_rounded, color: p.subText),
        ),
        IconButton(
          onPressed: () => _moveMonth(1),
          tooltip: '다음 달',
          icon: Icon(Icons.chevron_right_rounded, color: p.subText),
        ),
      ],
    );
  }

  Widget _buildCalendar(BuildContext context) {
    final p = context.palette;
    final text = context.text;
    final dayStyle = text.body.copyWith(color: p.titleText);
    BoxDecoration circle(Color c) =>
        BoxDecoration(color: c, shape: BoxShape.circle);

    return TableCalendar(
      firstDay: DateTime.utc(2020, 1, 1),
      lastDay: DateTime.utc(2035, 12, 31),
      focusedDay: _focusedDay,
      headerVisible: false,
      rowHeight: 46,
      daysOfWeekHeight: 28,
      startingDayOfWeek: StartingDayOfWeek.sunday,
      calendarFormat: CalendarFormat.month,
      availableCalendarFormats: const {CalendarFormat.month: '월'},
      availableGestures: AvailableGestures.horizontalSwipe,
      selectedDayPredicate: (day) => isSameDate(widget.selectedDay, day),
      onDaySelected: (selected, focused) {
        setState(() => _focusedDay = focused);
        widget.onDaySelected(selected);
      },
      onPageChanged: (focused) => setState(() => _focusedDay = focused),
      eventLoader: _eventsForDay,
      daysOfWeekStyle: DaysOfWeekStyle(
        dowTextFormatter: (date, _) => koWeekdayShort(date),
        weekdayStyle: text.micro,
        weekendStyle: text.micro,
      ),
      calendarStyle: CalendarStyle(
        cellMargin: const EdgeInsets.all(5),
        defaultTextStyle: dayStyle,
        weekendTextStyle: dayStyle,
        outsideTextStyle: dayStyle.copyWith(color: p.checkboxIdle),
        todayDecoration: circle(p.accentSoft),
        todayTextStyle: dayStyle.copyWith(
          color: p.accent,
          fontWeight: FontWeight.w800,
        ),
        selectedDecoration: circle(p.accent),
        selectedTextStyle: dayStyle.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w800,
        ),
        markerDecoration: circle(p.danger),
        markerSize: 5,
        markersMaxCount: 1,
        markerMargin: const EdgeInsets.only(top: 6),
      ),
    );
  }
}
