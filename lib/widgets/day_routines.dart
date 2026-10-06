import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/routine.dart';
import '../providers/routine_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'common/app_card.dart';
import 'common/section_header.dart';
import 'round_check.dart';

/// 메인 화면 '오늘의 루틴' 섹션: 캘린더에서 고른 날짜에 할 루틴 목록.
/// 오늘·지난 날은 탭해서 완료 체크, 제목 옆 '전체 보기'를 누르면 루틴 목록으로 간다.
class DayRoutines extends StatelessWidget {
  final DateTime day;
  final VoidCallback onOpenList;

  const DayRoutines({super.key, required this.day, required this.onOpenList});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final provider = context.watch<RoutineProvider>();
    final routines = provider.routinesOn(day);
    final isToday = isSameDate(day, DateTime.now());
    final canCheck = !day.isAfter(dateOnly(DateTime.now()));
    final done = routines.where((r) => r.isDoneOn(day)).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: isToday ? '오늘의 루틴' : '${formatDateWithWeekday(day)} 루틴',
          count: routines.isEmpty ? null : routines.length,
          countColor: palette.routine,
          dotColor: palette.routine,
          trailing: TextButton(
            onPressed: onOpenList,
            style: TextButton.styleFrom(foregroundColor: palette.subText),
            child: const Text('전체 보기 ›'),
          ),
        ),
        AppCard(
          onTap: routines.isEmpty ? onOpenList : null,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: routines.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.repeat_rounded,
                        size: 20,
                        color: palette.checkboxIdle,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        provider.routines.isEmpty
                            ? '루틴을 추가해 보세요'
                            : '이 날은 루틴이 없어요',
                        style: text.caption,
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < routines.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: palette.border),
                      _RoutineRow(
                        routine: routines[i],
                        day: day,
                        onTap: canCheck
                            ? () => provider.toggleDone(routines[i].id, day)
                            : onOpenList,
                      ),
                    ],
                    if (canCheck)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Text(
                          '${routines.length}개 중 $done개 완료',
                          style: text.micro.copyWith(color: palette.routine),
                        ),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _RoutineRow extends StatelessWidget {
  final Routine routine;
  final DateTime day;
  final VoidCallback onTap;

  const _RoutineRow({
    required this.routine,
    required this.day,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final done = routine.isDoneOn(day);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            RoundCheck(isDone: done, size: 22, color: palette.routine),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                routine.name,
                style: text.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: done ? palette.subText : palette.titleText,
                  decoration: done ? TextDecoration.lineThrough : null,
                  decorationColor: palette.subText,
                ),
              ),
            ),
            Text(routine.timeLabel, style: text.caption),
          ],
        ),
      ),
    );
  }
}
