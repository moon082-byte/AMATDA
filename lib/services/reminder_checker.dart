import '../models/task_item.dart';
import '../models/telegram_room.dart';

/// 지금 울려야 하는 리마인드 한 건
class DueReminder {
  /// 중복 알림 방지용 고유 키 (마감/리마인드를 바꾸면 키도 바뀌어 다시 울린다)
  final String key;
  final String title;
  final String body;

  const DueReminder({required this.key, required this.title, required this.body});
}

/// 마감까지 남은 시간을 짧게 표현한다 ("10분", "3시간", "2일")
String formatRemaining(Duration d) {
  if (d.inMinutes < 1) return '1분 미만';
  if (d.inHours < 1) return '${d.inMinutes}분';
  if (d.inDays < 1) return '${d.inHours}시간';
  return '${d.inDays}일';
}

String _body(DateTime due, DateTime now) {
  final left = due.difference(now);
  return left.isNegative
      ? '마감 시간이 지났어요'
      : '마감까지 ${formatRemaining(left)} 남았어요';
}

/// 알림 시각이 지났지만 아직 울리지 않은 리마인드를 모은다.
/// 마감이 12시간 넘게 지난 것은 이미 늦었으므로 건너뛴다.
List<DueReminder> collectDueReminders({
  required List<TaskItem> tasks,
  required List<TelegramRoom> rooms,
  required DateTime now,
  required Set<String> fired,
}) {
  final result = <DueReminder>[];
  final staleBefore = now.subtract(const Duration(hours: 12));

  void check(String kind, String id, String title, DateTime? at, DateTime? due) {
    if (at == null || due == null || at.isAfter(now) || due.isBefore(staleBefore)) {
      return;
    }
    final key = '$kind:$id:${at.toIso8601String()}';
    if (fired.contains(key)) return;
    result.add(DueReminder(key: key, title: title, body: _body(due, now)));
  }

  for (final t in tasks) {
    if (!t.isDone) check('task', t.id, t.title, t.reminderAt, t.dueDate);
  }
  for (final r in rooms) {
    check('room', r.id, '${r.name} 업무방', r.reminderAt, r.dueDate);
  }
  return result;
}
