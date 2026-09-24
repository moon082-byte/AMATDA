import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import '../theme/app_palette.dart';

/// 메인 화면 상단의 토스 스타일 캘린더 카드. 마감일이 있는 날짜에 마커를 표시한다.
class CalendarCard extends StatefulWidget {
  final List<DateTime> markedDates;

  const CalendarCard({super.key, required this.markedDates});

  @override
  State<CalendarCard> createState() => _CalendarCardState();
}

class _CalendarCardState extends State<CalendarCard> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<Object> _eventsForDay(DateTime day) {
    final hasEvent = widget.markedDates.any(
      (d) => d.year == day.year && d.month == day.month && d.day == day.day,
    );
    return hasEvent ? const [1] : const [];
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: BorderRadius.circular(AppPalette.cardRadius),
      ),
      child: TableCalendar(
        firstDay: DateTime.utc(2020, 1, 1),
        lastDay: DateTime.utc(2035, 12, 31),
        focusedDay: _focusedDay,
        selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
        onDaySelected: (selected, focused) {
          setState(() {
            _selectedDay = selected;
            _focusedDay = focused;
          });
        },
        onPageChanged: (focused) => _focusedDay = focused,
        eventLoader: _eventsForDay,
        calendarFormat: CalendarFormat.month,
        availableCalendarFormats: const {CalendarFormat.month: '월'},
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          titleTextStyle: TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 16,
            color: palette.titleText,
          ),
          leftChevronIcon: Icon(Icons.chevron_left, color: palette.subText),
          rightChevronIcon: Icon(Icons.chevron_right, color: palette.subText),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          weekdayStyle:
              TextStyle(color: palette.subText, fontWeight: FontWeight.w600),
          weekendStyle:
              TextStyle(color: palette.subText, fontWeight: FontWeight.w600),
        ),
        calendarStyle: CalendarStyle(
          defaultTextStyle: TextStyle(color: palette.titleText),
          weekendTextStyle: TextStyle(color: palette.titleText),
          outsideTextStyle: TextStyle(color: palette.checkboxIdle),
          todayDecoration: BoxDecoration(
            color: palette.accentChipBackground,
            shape: BoxShape.circle,
          ),
          todayTextStyle:
              TextStyle(color: palette.accent, fontWeight: FontWeight.w800),
          selectedDecoration:
              BoxDecoration(color: palette.accent, shape: BoxShape.circle),
          selectedTextStyle: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
          markerDecoration:
              BoxDecoration(color: palette.accent, shape: BoxShape.circle),
        ),
      ),
    );
  }
}
