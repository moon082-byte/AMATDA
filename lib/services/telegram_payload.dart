import '../models/routine.dart';
import '../models/task_item.dart';
import '../models/task_reminder.dart';
import '../models/telegram_room.dart';
import '../utils/date_format.dart';
import '../utils/links.dart';
import 'launch_link.dart';

/// 봇 서버에 한 번에 올릴 수 있는 알림 수 (봇 서버 MAX_REMINDERS와 같음)
const kMaxTelegramReminders = 300;

/// 루틴은 앞으로 이 일수만큼의 알림을 미리 올린다
const kRoutineDaysAhead = 7;

/// 봇 서버에 올릴 알림 일정을 만든다.
/// - 앞으로 울릴 알림은 모두 포함 (루틴은 앞으로 [kRoutineDaysAhead]일 치)
/// - 이미 지난 알림은 항목마다 가장 최근 것 하나만 포함(마감이 12시간 넘게 지났으면 제외)
/// - 메시지 문구는 이 기기 시간대 기준으로 미리 만들어 보낸다
/// - 메시지 아래 버튼: [앱에서 보기] + 업무방에 등록된 업무 링크
List<Map<String, Object>> buildTelegramReminders({
  required List<TaskItem> tasks,
  required List<TelegramRoom> rooms,
  List<Routine> routines = const [],
  required DateTime now,
}) {
  final result = <Map<String, Object>>[];
  final staleBefore = now.subtract(const Duration(hours: 12));

  void add(String kind, String id, DateTime? due, List<TaskReminder> reminders,
      String Function(TaskReminder) text, List<Map<String, String>> buttons) {
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
        'text': text(r),
        'buttons': buttons,
      });
    }
  }

  for (final t in tasks) {
    if (t.isDone) continue;
    final room = rooms.where((r) => r.id == t.roomId).firstOrNull;
    add('task', t.id, t.dueDate, t.reminders,
        (r) => _message(t.title, room?.name, t.dueDate!, r),
        _buttons('task', t.id, room?.workLinks ?? const []));
  }
  for (final room in rooms) {
    add('room', room.id, room.dueDate, room.reminders,
        (r) => _message('${room.name} 업무방 마감', null, room.dueDate!, r),
        _buttons('room', room.id, room.workLinks));
  }
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final until = now.add(const Duration(days: kRoutineDaysAhead));
  for (final routine in routines) {
    for (final at in routine.occurrences(yesterday, kRoutineDaysAhead + 2)) {
      if (at.isAfter(until) || routine.isDoneOn(at)) continue;
      // 같은 루틴이라도 날짜마다 다른 알림이므로 날짜를 붙여 구분한다
      add('routine', '${routine.id}:${dayKey(at)}', at, routine.remindersFor(at),
          (r) => _routineMessage(routine, at, r),
          _buttons('routine', routine.id, const []));
    }
  }

  // 너무 많으면 가까운 알림부터 남긴다 (나머지는 다음 동기화 때 올라간다)
  result.sort((a, b) => (a['fireAt'] as int).compareTo(b['fireAt'] as int));
  return result.take(kMaxTelegramReminders).toList();
}

List<Map<String, String>> _buttons(String kind, String id, List<String> links) => [
      {'text': '📱 앱에서 보기', 'url': appLinkFor(kind, id)},
      for (final link in links.map(normalizeUrl))
        if (link.startsWith('http')) {'text': _linkLabel(link), 'url': link},
    ];

/// "🔗 노션", 알 수 없는 곳이면 "🔗 example.com"
String _linkLabel(String url) {
  final (service, _) = linkService(url);
  return '🔗 ${service == '웹 링크' ? linkHost(url) : service}';
}

String _message(String title, String? roomName, DateTime due, TaskReminder r) {
  return [
    '🔔 리마인드 알림 (${r.label})',
    '',
    title,
    '⏰ 마감 ${formatDateWithWeekday(due)} ${formatTime(due)}',
    if (roomName != null) '🏷 $roomName',
  ].join('\n');
}

String _routineMessage(Routine routine, DateTime at, TaskReminder r) {
  return [
    '🔁 루틴 알림 (${r.label})',
    '',
    routine.name,
    '⏰ ${formatDateWithWeekday(at)} ${formatTime(at)} · ${routine.repeatLabel}',
  ].join('\n');
}
