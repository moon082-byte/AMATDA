import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/routine.dart';
import '../providers/routine_provider.dart';
import '../theme/app_palette.dart';
import '../utils/confirm_dialog.dart';
import '../utils/date_format.dart';
import '../widgets/common/app_page.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/section_header.dart';
import '../widgets/routine_tile.dart';
import 'form_routes.dart';

/// '루틴' 탭: 오늘 할 루틴(탭해서 완료 체크)과 다른 요일 루틴 목록.
/// 루틴을 왼쪽으로 밀면 수정/삭제할 수 있다.
class RoutineSlivers extends StatelessWidget {
  const RoutineSlivers({super.key});

  Future<void> _delete(BuildContext context, Routine routine) async {
    final confirmed = await confirmDelete(
      context,
      '"${routine.name}" 루틴을 삭제할까요?',
    );
    if (!context.mounted || !confirmed) return;
    context.read<RoutineProvider>().deleteRoutine(routine.id);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final provider = context.watch<RoutineProvider>();
    final today = dateOnly(DateTime.now());
    final todays = provider.routinesOn(today);
    final others = provider.routines.where((r) => !r.occursOn(today)).toList();

    Widget tile(Routine r, {required bool checkable}) => RoutineTile(
          key: ValueKey(r.id),
          routine: r,
          day: today,
          onToggle: checkable ? () => provider.toggleDone(r.id, today) : null,
          onEdit: () => openEditRoutine(context, r),
          onDelete: () => _delete(context, r),
        );

    if (provider.routines.isEmpty) {
      return paddedSliver(const [
        EmptyState(
          icon: Icons.repeat_rounded,
          title: '아직 루틴이 없어요',
          message: '아래 추가 버튼으로 매일·매주 반복할 습관을 만들어 보세요',
        ),
      ]);
    }

    return paddedSliver([
      SectionHeader(
        title: '오늘의 루틴',
        count: todays.length,
        countColor: palette.routine,
        dotColor: palette.routine,
      ),
      if (todays.isEmpty)
        const EmptyState(
          icon: Icons.free_breakfast_rounded,
          title: '오늘은 쉬는 날이에요',
        ),
      for (final r in todays) tile(r, checkable: true),
      if (others.isNotEmpty) ...[
        const SizedBox(height: 20),
        SectionHeader(
          title: '다른 요일 루틴',
          count: others.length,
          countColor: palette.subText,
        ),
        for (final r in others) tile(r, checkable: false),
      ],
    ]);
  }
}
