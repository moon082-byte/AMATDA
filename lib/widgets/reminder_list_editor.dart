import 'package:flutter/material.dart';
import '../models/task_reminder.dart';
import '../services/browser_notifications.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'field_label.dart';
import 'reminder_row.dart';
import 'reminder_unit_selector.dart';

/// 리마인드 여러 개(최대 [TaskReminder.maxCount]개) 편집기.
/// 할 일과 업무방이 함께 쓴다. 마감 기한이 없으면 추가할 수 없다.
class ReminderListEditor extends StatefulWidget {
  final String label;
  final DateTime? dueDate;
  final List<TaskReminder> value;
  final ValueChanged<List<TaskReminder>> onChanged;

  const ReminderListEditor({
    super.key,
    required this.label,
    required this.dueDate,
    required this.value,
    required this.onChanged,
  });

  @override
  State<ReminderListEditor> createState() => _ReminderListEditorState();
}

class _ReminderListEditorState extends State<ReminderListEditor> {
  // 줄마다 고정된 id를 붙여 중간 줄을 지워도 입력 상태가 섞이지 않게 한다
  late final List<int> _ids = List.generate(widget.value.length, (i) => i);
  late int _nextId = widget.value.length;

  bool get _isFull => widget.value.length >= TaskReminder.maxCount;

  void _add(TaskReminder r) {
    if (_isFull || widget.value.contains(r)) return;
    // 처음 추가할 때 브라우저 알림 권한을 요청한다 (사용자 탭에서만 요청 가능)
    if (notificationPermission() == 'default') requestNotificationPermission();
    _ids.add(_nextId++);
    widget.onChanged([...widget.value, r]);
  }

  void _replace(int index, TaskReminder r) =>
      widget.onChanged([...widget.value]..[index] = r);

  void _remove(int index) {
    _ids.removeAt(index);
    widget.onChanged([...widget.value]..removeAt(index));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final due = widget.dueDate;
    final count = widget.value.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FieldLabel(
          count == 0
              ? widget.label
              : '${widget.label} ($count/${TaskReminder.maxCount})',
        ),
        if (due == null)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: palette.fill,
              borderRadius: BorderRadius.circular(AppPalette.fieldRadius),
            ),
            child: Text(
              '마감 기한을 정하면 알림을 추가할 수 있어요',
              style: text.body.copyWith(color: palette.subText),
            ),
          )
        else ...[
          for (var i = 0; i < count; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: ReminderRow(
                key: ValueKey(_ids[i]),
                value: widget.value[i],
                dueDate: due,
                onChanged: (r) => _replace(i, r),
                onRemove: () => _remove(i),
              ),
            ),
          if (_isFull)
            Text('알림은 최대 ${TaskReminder.maxCount}개까지 추가할 수 있어요',
                style: text.caption)
          else ...[
            if (count == 0)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('아래에서 알림 시점을 골라 추가해 보세요',
                    style: text.caption),
              ),
            ReminderPresets(selected: widget.value, onSelected: _add),
          ],
        ],
      ],
    );
  }
}
