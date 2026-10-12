import 'package:flutter/material.dart';
import '../models/task_reminder.dart';
import '../services/browser_notifications.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'reminder_dropdown_row.dart';

/// 리마인더 공통 팝업 (할 일·루틴·세부 항목).
/// "N단위 전" 알림을 최대 [TaskReminder.maxCount]개까지 고른다.
/// [dueDate]는 알림 기준 시각(마감 또는 다음 루틴 시각). 취소하면 null을 돌려준다.
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

  bool get _isFull => _list.length >= TaskReminder.maxCount;

  void _add() {
    if (_isFull) return;
    // 처음 추가할 때 브라우저 알림 권한을 요청한다 (사용자 탭에서만 요청 가능)
    if (notificationPermission() == 'default') requestNotificationPermission();
    final next = _suggested.firstWhere(
      (r) => !_list.contains(r),
      orElse: () => _suggested.first,
    );
    setState(() {
      _list.add(next);
      _ids.add(_nextId++);
    });
  }

  void _remove(int i) => setState(() {
        _list.removeAt(i);
        _ids.removeAt(i);
      });

  /// 같은 값이 여러 줄이면 하나만 남긴다
  void _confirm() => Navigator.pop(context, _list.toSet().toList());

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.title, style: text.h2, maxLines: 2),
            const SizedBox(height: 4),
            Text(
              '알림 ${_list.length}/${TaskReminder.maxCount}',
              style: text.caption,
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (var i = 0; i < _list.length; i++)
                      Padding(
                        key: ValueKey(_ids[i]),
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ReminderDropdownRow(
                          value: _list[i],
                          dueDate: widget.dueDate,
                          onChanged: (r) => setState(() => _list[i] = r),
                          onRemove: () => _remove(i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _isFull ? null : _add,
              icon: const Icon(Icons.add_rounded),
              label: Text(_isFull
                  ? '알림은 최대 ${TaskReminder.maxCount}개까지예요'
                  : '리마인더 추가'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context),
                    style: FilledButton.styleFrom(
                      backgroundColor: palette.fill,
                      foregroundColor: palette.bodyText,
                    ),
                    child: const Text('취소'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: _confirm,
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
