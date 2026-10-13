import 'package:flutter/material.dart';
import '../models/task_reminder.dart';
import 'remind_at_row.dart';
import 'reminder_popup_frame.dart';

/// 할 일·세부 항목 리마인더 팝업: 알림 날짜·시간을 직접 골라 최대 [TaskReminder.maxCount]개 건다.
/// [dueDate]는 마감 일시(없어도 된다, 안내·기본값용). 취소하면 null을 돌려준다.
Future<List<DateTime>?> showRemindAtPopup(
  BuildContext context, {
  required List<DateTime> initial,
  DateTime? dueDate,
  String title = '리마인더',
}) {
  return showDialog<List<DateTime>>(
    context: context,
    builder: (_) =>
        _RemindAtPopup(initial: initial, dueDate: dueDate, title: title),
  );
}

class _RemindAtPopup extends StatefulWidget {
  final List<DateTime> initial;
  final DateTime? dueDate;
  final String title;

  const _RemindAtPopup(
      {required this.initial, required this.dueDate, required this.title});

  @override
  State<_RemindAtPopup> createState() => _RemindAtPopupState();
}

class _RemindAtPopupState extends State<_RemindAtPopup> {
  late final List<DateTime> _list = [...widget.initial];
  // 줄마다 고정된 id를 붙여 중간 줄을 지워도 상태가 섞이지 않게 한다
  late final List<int> _ids = List.generate(_list.length, (i) => i);
  late int _nextId = _list.length;

  /// 새 줄 기본값: 마감 1시간 전(이미 지났거나 마감이 없으면 지금부터 1시간 뒤 정각).
  /// 이미 있는 시각이면 1시간씩 뒤로 민다.
  DateTime _suggest() {
    final now = DateTime.now();
    final beforeDue = widget.dueDate?.subtract(const Duration(hours: 1));
    var at = beforeDue != null && beforeDue.isAfter(now)
        ? beforeDue
        : DateTime(now.year, now.month, now.day, now.hour + 1);
    while (_list.contains(at)) {
      at = at.add(const Duration(hours: 1));
    }
    return at;
  }

  void _add() => setState(() {
        _list.add(_suggest());
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
      // 같은 시각은 하나만 남기고 이른 순으로 저장한다
      onConfirm: () => Navigator.pop(context, normalizeRemindAt(_list)),
      rows: [
        for (var i = 0; i < _list.length; i++)
          RemindAtRow(
            key: ValueKey(_ids[i]),
            value: _list[i],
            dueDate: widget.dueDate,
            onChanged: (at) => setState(() => _list[i] = at),
            onRemove: () => _remove(i),
          ),
      ],
    );
  }
}
