import '../models/routine.dart';
import '../models/task_item.dart';

/// 지금 울려야 하는 리마인드 한 건
class DueReminder {
  /// 중복 알림 방지용 고유 키 (마감/리마인드를 바꾸면 키도 바뀌어 다시 울린다)
  final String key;
  final String title;
  final String body;

  /// 함께 '울린 것'으로 기록할 키들 (한꺼번에 지난 다른 알림 시각 포함)
  final List<String> alsoCovers;

  const DueReminder({
    required this.key,
    required this.title,
    required this.body,
    this.alsoCovers = const [],
  });
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

String _routineBody(DateTime at, DateTime now) {
  final left = at.difference(now);
  return left.inMinutes < 1
      ? '루틴 시간이에요'
      : '${formatRemaining(left)} 뒤 루틴 시간이에요';
}

/// 루틴 알림을 확인할 기간: 어제부터 가장 이른 리마인드가 닿는 날까지 (최대 5주)
int routineWindowDays(Routine r) {
  final longest = r.reminders.fold(Duration.zero,
      (max, rem) => rem.offset > max ? rem.offset : max);
  return (longest.inDays + 2).clamp(2, 36);
}

/// 알림 시각이 지났지만 아직 울리지 않은 리마인드를 모은다.
/// 마감이 12시간 넘게 지난 것은 이미 늦었으므로 건너뛴다.
List<DueReminder> collectDueReminders({
  required List<TaskItem> tasks,
  List<Routine> routines = const [],
  required DateTime now,
  required Set<String> fired,
}) {
  final result = <DueReminder>[];
  final staleBefore = now.subtract(const Duration(hours: 12));

  void check(String kind, String id, String title, List<DateTime> times,
      DateTime? due, [String Function(DateTime, DateTime) body = _body]) {
    if (due == null || due.isBefore(staleBefore)) return;
    // 여러 알림 시각이 한꺼번에 지났으면(앱을 오래 닫아 둔 경우) 한 번만 알린다
    final passed = times.where((at) => !at.isAfter(now)).toList();
    final keys = [for (final at in passed) '$kind:$id:${at.toIso8601String()}'];
    final fresh = keys.where((k) => !fired.contains(k)).toList();
    if (fresh.isEmpty) return;
    result.add(DueReminder(
      key: fresh.last,
      title: title,
      body: body(due, now),
      alsoCovers: keys,
    ));
  }

  for (final t in tasks) {
    if (!t.isDone) check('task', t.id, t.title, t.reminderTimes, t.dueDate);
  }
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  for (final r in routines) {
    for (final at in r.occurrences(yesterday, routineWindowDays(r))) {
      if (r.isDoneOn(at)) continue;
      final times = [for (final rem in r.remindersFor(at)) rem.fireAt(at)];
      check('routine', r.id, '${r.name} 루틴', times, at, _routineBody);
    }
  }
  return result;
}
