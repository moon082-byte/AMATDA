import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import '../utils/task_actions.dart';
import 'common/app_card.dart';
import 'common/section_header.dart';
import 'round_check.dart';

/// 메인 화면 '오늘의 일정' 섹션: 캘린더에서 고른 날짜에 마감인 할 일 목록.
/// 할 일을 누르면 '오늘 할일'에서 펼쳐서 보여주고, 체크는 왼쪽 동그라미를 눌렀을 때만 된다.
/// 제목 옆 '전체 보기'를 누르면 '오늘 할일'로 간다.
class DayAgenda extends StatelessWidget {
  final DateTime day;
  final VoidCallback onOpenList;
  final ValueChanged<TaskItem> onOpenTask;

  const DayAgenda({
    super.key,
    required this.day,
    required this.onOpenList,
    required this.onOpenTask,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final provider = context.watch<RoomProvider>();
    final tasks =
        provider.tasks
            .where((t) => t.dueDate != null && isSameDate(t.dueDate!, day))
            .toList()
          ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: isSameDate(day, DateTime.now())
              ? '오늘의 일정'
              : '${formatDateWithWeekday(day)} 일정',
          count: tasks.isEmpty ? null : tasks.length,
          dotColor: palette.accent,
          trailing: TextButton(
            onPressed: onOpenList,
            style: TextButton.styleFrom(foregroundColor: palette.subText),
            child: const Text('전체 보기 ›'),
          ),
        ),
        AppCard(
          onTap: tasks.isEmpty ? onOpenList : null,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
          child: tasks.isEmpty
              ? Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: Row(
                    children: [
                      Icon(
                        Icons.event_available_rounded,
                        size: 20,
                        color: palette.checkboxIdle,
                      ),
                      const SizedBox(width: 10),
                      Text('이 날은 마감 일정이 없어요', style: text.caption),
                    ],
                  ),
                )
              : Column(
                  children: [
                    for (var i = 0; i < tasks.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: palette.border),
                      _AgendaRow(
                        task: tasks[i],
                        provider: provider,
                        onOpen: () => onOpenTask(tasks[i]),
                      ),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _AgendaRow extends StatelessWidget {
  final TaskItem task;
  final RoomProvider provider;
  final VoidCallback onOpen;

  const _AgendaRow({
    required this.task,
    required this.provider,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final due = task.dueDate!;
    final roomName = provider.roomById(task.roomId ?? '')?.name;
    final hasTime = due.hour != 0 || due.minute != 0;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onOpen,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            RoundCheckButton(
              isDone: task.isDone,
              size: 22,
              width: 40,
              alignment: Alignment.centerLeft,
              onTap: () => task.isDone
                  ? restoreTask(context, task)
                  : toggleTaskWithUndo(context, task),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: text.body.copyWith(
                      fontWeight: FontWeight.w600,
                      color: task.isDone ? palette.subText : palette.titleText,
                      decoration: task.isDone
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: palette.subText,
                    ),
                  ),
                  if (roomName != null) Text(roomName, style: text.micro),
                ],
              ),
            ),
            Text(hasTime ? formatTime(due) : '종일', style: text.caption),
          ],
        ),
      ),
    );
  }
}
