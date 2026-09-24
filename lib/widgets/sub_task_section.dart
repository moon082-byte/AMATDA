import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/sub_task.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';

/// 할 일 상세에서 하위 세부 체크리스트를 보여주고 추가하는 섹션
class SubTaskSection extends StatefulWidget {
  final TaskItem task;

  const SubTaskSection({super.key, required this.task});

  @override
  State<SubTaskSection> createState() => _SubTaskSectionState();
}

class _SubTaskSectionState extends State<SubTaskSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addSubTask() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final subTask = SubTask(
      id: 'sub_${DateTime.now().millisecondsSinceEpoch}',
      title: text,
    );
    context.read<RoomProvider>().addSubTask(widget.task.id, subTask);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final task =
        context.watch<RoomProvider>().taskById(widget.task.id) ?? widget.task;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '세부 체크리스트',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: palette.subText,
          ),
        ),
        const SizedBox(height: 8),
        ...task.subTasks.map(
          (sub) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context
                      .read<RoomProvider>()
                      .toggleSubTask(task.id, sub.id),
                  child: Icon(
                    sub.isDone ? Icons.check_circle : Icons.circle_outlined,
                    size: 20,
                    color: sub.isDone ? palette.accent : palette.checkboxIdle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    sub.title,
                    style: TextStyle(
                      fontSize: 14,
                      decoration: sub.isDone
                          ? TextDecoration.lineThrough
                          : TextDecoration.none,
                      color: sub.isDone ? palette.subText : palette.titleText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: TextStyle(fontSize: 14, color: palette.titleText),
                decoration: InputDecoration(
                  hintText: '세부 항목 추가',
                  isDense: true,
                  filled: true,
                  fillColor: palette.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _addSubTask(),
              ),
            ),
            IconButton(
              onPressed: _addSubTask,
              icon: Icon(Icons.add_circle, color: palette.accent),
            ),
          ],
        ),
      ],
    );
  }
}
