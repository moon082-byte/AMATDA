import '../config/bot_config.dart';
import '../models/task_item.dart';
import '../models/task_reminder.dart';
import '../models/telegram_room.dart';
import '../utils/date_format.dart';

/// 봇 서버에 올릴 알림 일정을 만든다.
/// - 앞으로 울릴 알림은 모두 포함
/// - 이미 지난 알림은 항목마다 가장 최근 것 하나만 포함(마감이 12시간 넘게 지났으면 제외)
/// - 메시지 문구는 이 기기 시간대 기준으로 미리 만들어 보낸다
List<Map<String, Object>> buildTelegramReminders({
  required List<TaskItem> tasks,
  required List<TelegramRoom> rooms,
  required DateTime now,
}) {
  final result = <Map<String, Object>>[];
  final staleBefore = now.subtract(const Duration(hours: 12));

  void add(String kind, String id, String title, String? roomName,
      DateTime? due, List<TaskReminder> reminders) {
    if (due == null || due.isBefore(staleBefore) || reminders.isEmpty) return;
    final sorted = sortReminders(reminders);
    final passed = sorted.where((r) => !r.fireAt(due).isAfter(now));
    final picked = [
      if (passed.isNotEmpty) passed.last,
      ...sorted.where((r) => r.fireAt(due).isAfter(now)),
    ];
    for (final r in picked) {
      final at = r.fireAt(due);
      result.add({
        'key': '$kind:$id:${at.toUtc().toIso8601String()}',
        'fireAt': at.millisecondsSinceEpoch,
        'dueAt': due.millisecondsSinceEpoch,
        'text': _message(title, roomName, due, r),
      });
    }
  }

  for (final t in tasks) {
    if (t.isDone) continue;
    final roomName = rooms.where((r) => r.id == t.roomId).firstOrNull?.name;
    add('task', t.id, t.title, roomName, t.dueDate, t.reminders);
  }
  for (final r in rooms) {
    add('room', r.id, '${r.name} 업무방 마감', null, r.dueDate, r.reminders);
  }
  return result;
}

String _message(String title, String? roomName, DateTime due, TaskReminder r) {
  return [
    '🔔 리마인드 알림 (${r.label})',
    '',
    title,
    '⏰ 마감 ${formatDateWithWeekday(due)} ${formatTime(due)}',
    if (roomName != null) '🏷 $roomName',
    '',
    kAppUrl,
  ].join('\n');
}
