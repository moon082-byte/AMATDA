import 'package:flutter/material.dart';
import '../models/task_item.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/overdue_actions.dart';
import 'common/app_card.dart';
import 'task_meta_chips.dart';

/// [기한 지남] 탭의 할 일 한 줄: 제목·마감 정보와 [기한 변경]/[미완료 처리] 버튼.
/// 프로젝트에서 배정된 업무는 담당자가 마감을 바꿀 수 없어 [미완료 처리]만 보인다.
class OverdueTaskCard extends StatefulWidget {
  final TaskItem task;
  final String? roomName;

  /// 알림을 눌러 들어온 할 일이면 테두리로 표시하고 화면에 보이게 한다
  final bool focused;

  const OverdueTaskCard({super.key, required this.task, this.roomName, this.focused = false});

  @override
  State<OverdueTaskCard> createState() => _OverdueTaskCardState();
}

class _OverdueTaskCardState extends State<OverdueTaskCard> {
  @override
  void initState() {
    super.initState();
    if (widget.focused) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Scrollable.ensureVisible(context, alignment: 0.1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final task = widget.task;
    final buttonStyle = OutlinedButton.styleFrom(
      minimumSize: const Size(0, 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        border: widget.focused ? Border.all(color: palette.danger, width: 1.5) : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task.title, style: text.title),
            const SizedBox(height: 8),
            TaskMetaChips(task: task, roomName: widget.roomName),
            const SizedBox(height: 14),
            Row(
              children: [
                if (!task.isProjectTask) ...[
                  Expanded(
                    child: OutlinedButton.icon(
                      style: buttonStyle,
                      onPressed: () => changeOverdueDue(context, task),
                      icon: const Icon(Icons.event_rounded, size: 18),
                      label: const Text('기한 변경'),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: OutlinedButton.icon(
                    style: buttonStyle.copyWith(
                      foregroundColor: WidgetStatePropertyAll(palette.subText),
                    ),
                    onPressed: () => markOverdueMissed(context, task),
                    icon: const Icon(Icons.remove_circle_outline_rounded, size: 18),
                    label: const Text('미완료 처리'),
                  ),
                ),
              ],
            ),
            if (task.isProjectTask) ...[
              const SizedBox(height: 8),
              Text('프로젝트 업무의 마감은 팀장만 바꿀 수 있어요', style: text.micro),
            ],
          ],
        ),
      ),
    );
  }
}
