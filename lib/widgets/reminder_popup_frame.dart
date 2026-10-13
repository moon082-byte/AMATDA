import 'package:flutter/material.dart';
import '../models/task_reminder.dart';
import '../services/browser_notifications.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// 리마인더 팝업 공통 틀: 제목, 알림 줄들, [+ 리마인더 추가], [취소][확인].
/// 할 일·세부 항목(날짜·시간 지정)과 루틴(N단위 전)이 함께 쓴다.
class ReminderPopupFrame extends StatelessWidget {
  final String title;
  final List<Widget> rows;
  final VoidCallback onAdd;
  final VoidCallback onConfirm;

  const ReminderPopupFrame({
    super.key,
    required this.title,
    required this.rows,
    required this.onAdd,
    required this.onConfirm,
  });

  bool get _isFull => rows.length >= TaskReminder.maxCount;

  void _add() {
    // 처음 추가할 때 브라우저 알림 권한을 요청한다 (사용자 탭에서만 요청 가능)
    if (notificationPermission() == 'default') requestNotificationPermission();
    onAdd();
  }

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
            Text(title, style: text.h2, maxLines: 2),
            const SizedBox(height: 4),
            Text('알림 ${rows.length}/${TaskReminder.maxCount}', style: text.caption),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    for (final row in rows)
                      Padding(
                        key: row.key,
                        padding: const EdgeInsets.only(bottom: 8),
                        child: row,
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
                    onPressed: onConfirm,
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
