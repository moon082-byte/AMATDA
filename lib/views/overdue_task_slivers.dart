import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/room_provider.dart';
import '../widgets/common/app_page.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/common/section_header.dart';
import '../widgets/overdue_task_card.dart';

/// '기한 지남' 탭: 마감이 지났는데 끝내지 않은 할 일. 마감을 다시 정하거나 미완료로 처리한다.
class OverdueTaskSlivers extends StatelessWidget {
  final String? focusTaskId;

  const OverdueTaskSlivers({super.key, this.focusTaskId});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RoomProvider>();
    final tasks = provider.overdueTasks;

    return SliverMainAxisGroup(
      slivers: [
        paddedSliver([
          SectionHeader(title: '기한 지난 할 일', count: tasks.length),
          if (tasks.isEmpty)
            const EmptyState(
              icon: Icons.verified_rounded,
              title: '기한 지난 할 일이 없어요',
              message: '마감이 지나면 여기에서 기한을 바꾸거나 미완료로 처리해요',
            ),
        ]),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList.builder(
            itemCount: tasks.length,
            itemBuilder: (context, index) {
              final task = tasks[index];
              return OverdueTaskCard(
                key: ValueKey(task.id),
                task: task,
                focused: task.id == focusTaskId,
                roomName: provider.roomById(task.roomId ?? '')?.name,
              );
            },
          ),
        ),
      ],
    );
  }
}
