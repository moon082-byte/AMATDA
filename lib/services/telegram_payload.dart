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
/// - 할 일 알림에는 [업무링크](업무방에 등록한 링크) 줄을 넣는다 (없으면 뺀다)
/// - 할 일·세부 항목 알림은 직접 고른 시각에 보내고, 세부 항목은 할 일명과 [세부항목]을 함께 보낸다
/// - 메시지 아래 [앱에서 보기] 버튼: 누르면 해당 항목 화면이 바로 열린다
List<Map<String, Object>> buildTelegramReminders({
  required List<TaskItem> tasks,
  required List<TelegramRoom> rooms,
  List<Routine> routines = const [],
  required DateTime now,
}) {
  final result = <Map<String, Object>>[];
  final staleBefore = now.subtract(const Duration(hours: 12));

  void add(String kind, String id, DateTime? due, List<DateTime> times,
      String Function(DateTime at) text, String openKind, String openId) {
    final sorted = normalizeRemindAt(times);
    final passed = sorted.where((at) => !at.isAfter(now));
    final picked = [
      if (passed.isNotEmpty) passed.last,
      ...sorted.where((at) => at.isAfter(now)),
    ];
    for (final at in picked) {
      // 마감이 없으면 알림 시각 자체를 기준으로 오래된 것을 거른다
      final ref = due ?? at;
      if (ref.isBefore(staleBefore)) continue;
      result.add({
        'key': '$kind:$id:${at.toUtc().toIso8601String()}',
        'fireAt': at.millisecondsSinceEpoch,
        'dueAt': ref.millisecondsSinceEpoch,
        'text': text(at),
        'buttons': [
          {'text': '📱 앱에서 보기', 'url': appLinkFor(openKind, openId)},
        ],
      });
    }
  }

  for (final t in tasks) {
    if (t.isDone) continue;
    final workLinks =
        rooms.where((r) => r.id == t.roomId).firstOrNull?.workLinks ?? const [];
    add('task', t.id, t.dueDate, t.remindAt,
        (at) => _message(t.title, at, t.dueDate, workLinks), 'task', t.id);
    for (final s in t.subTasks.where((s) => !s.isDone)) {
      add('sub', '${t.id}:${s.id}', t.dueDate, s.remindAt,
          (at) => _message(t.title, at, t.dueDate, workLinks, s.title),
          'task', t.id);
    }
  }
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final until = now.add(const Duration(days: kRoutineDaysAhead));
  for (final routine in routines) {
    for (final at in routine.occurrences(yesterday, kRoutineDaysAhead + 2)) {
      if (at.isAfter(until) || routine.isDoneOn(at)) continue;
      final labels = {for (final r in routine.remindersFor(at)) r.fireAt(at): r.label};
      // 같은 루틴이라도 날짜마다 다른 알림이므로 날짜를 붙여 구분한다
      add('routine', '${routine.id}:${dayKey(at)}', at, [...labels.keys],
          (t) => _routineMessage(routine, at, labels[t]!), 'routine', routine.id);
    }
  }

  // 너무 많으면 가까운 알림부터 남긴다 (나머지는 다음 동기화 때 올라간다)
  result.sort((a, b) => (a['fireAt'] as int).compareTo(b['fireAt'] as int));
  return result.take(kMaxTelegramReminders).toList();
}

String _dateTime(DateTime d) => '${formatDateWithWeekday(d)} ${formatTime(d)}';

String _message(String title, DateTime at, DateTime? due, List<String> workLinks,
    [String? subTitle]) {
  return [
    '[체크리스트 업무] $title',
    if (subTitle != null) '[세부항목] $subTitle',
    '[알림시각] ${_dateTime(at)}',
    if (due != null) '[마감기한] ${_dateTime(due)}',
    for (final link in workLinks.map(normalizeUrl))
      if (link.startsWith('http')) '[업무링크] $link',
  ].join('\n');
}

String _routineMessage(Routine routine, DateTime at, String label) {
  return [
    '[루틴] ${routine.name}',
    '[일시] ${formatDateWithWeekday(at)} ${formatTime(at)} · ${routine.repeatLabel} ($label)',
  ].join('\n');
}
