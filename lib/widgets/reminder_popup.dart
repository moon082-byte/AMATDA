import 'package:flutter/material.dart';
import '../models/task_reminder.dart';
import 'reminder_dropdown_row.dart';
import 'reminder_popup_frame.dart';

/// 루틴 리마인더 팝업: 회차 시각 "N단위 전" 알림을 최대 [TaskReminder.maxCount]개 고른다.
/// [dueDate]는 다음 루틴 시각(알림 시각 안내용). 취소하면 null을 돌려준다.
Future<List<TaskReminder>?> showReminderPopup(
  BuildContext context, {
  required List<TaskReminder> initial,
  required DateTime dueDate,
  String title = '리마인더',
}) {
  return showDialog<List<TaskReminder>>(
    context: context,
    builder: (_) =>
        _ReminderPopup(initial: initial, dueDate: dueDate, title: title),
  );
}

class _ReminderPopup extends StatefulWidget {
  final List<TaskReminder> initial;
  final DateTime dueDate;
  final String title;

  const _ReminderPopup(
      {required this.initial, required this.dueDate, required this.title});

  @override
  State<_ReminderPopup> createState() => _ReminderPopupState();
}

class _ReminderPopupState extends State<_ReminderPopup> {
  /// 새로 추가할 때 아직 없는 값 중 앞의 것부터 넣는다
  static const _suggested = [
    TaskReminder(amount: 10, unit: ReminderUnit.minute),
    TaskReminder(amount: 30, unit: ReminderUnit.minute),
    TaskReminder(amount: 1, unit: ReminderUnit.hour),
    TaskReminder(amount: 1, unit: ReminderUnit.day),
    TaskReminder(amount: 0, unit: ReminderUnit.minute),
    TaskReminder(amount: 1, unit: ReminderUnit.week),
  ];

  late final List<TaskReminder> _list = [...widget.initial];
  // 줄마다 고정된 id를 붙여 중간 줄을 지워도 입력 상태가 섞이지 않게 한다
  late final List<int> _ids = List.generate(_list.length, (i) => i);
  late int _nextId = _list.length;

  void _add() => setState(() {
        _list.add(_suggested.firstWhere(
          (r) => !_list.contains(r),
          orElse: () => _suggested.first,
        ));
        _ids.add(_nextId++);
      });

  void _remove(int i) => setState(() {
        _list.removeAt(i);
        _ids.removeAt(i);
      });

  @override
  Widget build(BuildContext context) {
    return ReminderPopupFrame(
      title: widget.title,
      onAdd: _add,
      // 같은 값이 여러 줄이면 하나만 남긴다
      onConfirm: () => Navigator.pop(context, _list.toSet().toList()),
      rows: [
        for (var i = 0; i < _list.length; i++)
          ReminderDropdownRow(
            key: ValueKey(_ids[i]),
            value: _list[i],
            dueDate: widget.dueDate,
            onChanged: (r) => setState(() => _list[i] = r),
            onRemove: () => _remove(i),
          ),
      ],
    );
  }
}
