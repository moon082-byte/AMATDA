import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';
import '../../utils/d_day.dart';
import '../../utils/date_format.dart';
import 'tag_chip.dart';

/// 마감 긴급도에 따라 색이 바뀌는 마감 배지.
/// [dDay]가 true면 "D-3" 형식, 아니면 "오늘 18:00" 같은 상대 날짜로 표시한다.
class DueBadge extends StatelessWidget {
  final DateTime? dueDate;
  final bool dDay;
  final bool isDone;

  const DueBadge({
    super.key,
    required this.dueDate,
    this.dDay = false,
    this.isDone = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final date = dueDate;
    if (date == null) {
      return TagChip.neutral(context, '마감 없음');
    }

    final label = dDay ? formatDDay(date) : formatRelativeDateTime(date);
    final (fg, bg) = switch (dueUrgency(date, isDone: isDone)) {
      DueUrgency.overdue => (p.danger, p.dangerSoft),
      DueUrgency.today => (p.warning, p.warningSoft),
      DueUrgency.soon => (p.accent, p.accentSoft),
      DueUrgency.later || DueUrgency.none => (p.bodyText, p.fill),
    };

    return TagChip(
      label: label,
      foreground: fg,
      background: bg,
      icon: dDay ? null : Icons.schedule_rounded,
    );
  }
}
