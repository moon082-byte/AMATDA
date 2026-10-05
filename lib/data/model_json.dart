import '../models/note.dart';
import '../models/sub_task.dart';
import '../models/task_item.dart';
import '../models/task_reminder.dart';
import '../models/telegram_room.dart';

/// 브라우저/기기 저장소에 넣기 위한 모델 ↔ JSON 변환

String? _date(DateTime? d) => d?.toIso8601String();
DateTime? _parseDate(Object? v) => v is String ? DateTime.tryParse(v) : null;

T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
  for (final v in values) {
    if (v.name == name) return v;
  }
  return fallback;
}

Map<String, Object?> roomToJson(TelegramRoom r) => {
      'id': r.id,
      'name': r.name,
      'type': r.type.name,
      'inviteLink': r.inviteLink,
      'memberCount': r.memberCount,
      'profileImageUrl': r.profileImageUrl,
      'isPinned': r.isPinned,
      'unreadCount': r.unreadCount,
      'lastActivityAt': _date(r.lastActivityAt),
      'dueDate': _date(r.dueDate),
      'reminders': _remindersToJson(r.reminders),
      'workLinks': r.workLinks,
    };

TelegramRoom roomFromJson(Map<String, dynamic> j) => TelegramRoom(
      id: j['id'] as String,
      name: j['name'] as String,
      type: _enumByName(
          TelegramRoomType.values, j['type'], TelegramRoomType.group),
      inviteLink: (j['inviteLink'] as String?) ?? '',
      memberCount: (j['memberCount'] as int?) ?? 1,
      profileImageUrl: j['profileImageUrl'] as String?,
      isPinned: (j['isPinned'] as bool?) ?? false,
      unreadCount: (j['unreadCount'] as int?) ?? 0,
      lastActivityAt: _parseDate(j['lastActivityAt']) ?? DateTime.now(),
      dueDate: _parseDate(j['dueDate']),
      reminders: _remindersFromJson(j['reminders']) ??
          _legacyRoomReminder(j['reminderOption']),
      workLinks: [
        for (final link in (j['workLinks'] as List? ?? const [])) '$link',
      ],
    );

Map<String, Object?> taskToJson(TaskItem t) => {
      'id': t.id,
      'title': t.title,
      'description': t.description,
      'isDone': t.isDone,
      'dueDate': _date(t.dueDate),
      'completedAt': _date(t.completedAt),
      'priority': t.priority.name,
      'roomId': t.roomId,
      'createdAt': _date(t.createdAt),
      'subTasks': [
        for (final s in t.subTasks)
          {'id': s.id, 'title': s.title, 'isDone': s.isDone},
      ],
      'notes': [
        for (final n in t.notes)
          {'id': n.id, 'content': n.content, 'createdAt': _date(n.createdAt)},
      ],
      'reminders': _remindersToJson(t.reminders),
    };

TaskItem taskFromJson(Map<String, dynamic> j) => TaskItem(
      id: j['id'] as String,
      title: j['title'] as String,
      description: j['description'] as String?,
      isDone: (j['isDone'] as bool?) ?? false,
      dueDate: _parseDate(j['dueDate']),
      completedAt: _parseDate(j['completedAt']),
      priority: _enumByName(
          TaskPriority.values, j['priority'], TaskPriority.medium),
      roomId: j['roomId'] as String?,
      createdAt: _parseDate(j['createdAt']) ?? DateTime.now(),
      subTasks: [
        for (final s in (j['subTasks'] as List? ?? const []))
          SubTask(
            id: s['id'] as String,
            title: s['title'] as String,
            isDone: (s['isDone'] as bool?) ?? false,
          ),
      ],
      notes: [
        for (final n in (j['notes'] as List? ?? const []))
          Note(
            id: n['id'] as String,
            content: n['content'] as String,
            createdAt: _parseDate(n['createdAt']) ?? DateTime.now(),
          ),
      ],
      reminders: _remindersFromJson(j['reminders']) ??
          [?_reminderFromJson(j['reminder'])],
    );

TaskReminder? _reminderFromJson(Object? v) {
  if (v is! Map || v['amount'] is! int) return null;
  return TaskReminder(
    amount: v['amount'] as int,
    unit: _enumByName(ReminderUnit.values, v['unit'], ReminderUnit.minute),
  );
}

List<Map<String, Object>> _remindersToJson(List<TaskReminder> list) =>
    [for (final r in list) {'amount': r.amount, 'unit': r.unit.name}];

List<TaskReminder>? _remindersFromJson(Object? v) {
  if (v is! List) return null;
  return [
    for (final item in v) ?_reminderFromJson(item),
  ].take(TaskReminder.maxCount).toList();
}

/// 예전 저장 형식(업무방 리마인더 선택지 1개)을 새 형식으로 바꾼다
List<TaskReminder> _legacyRoomReminder(Object? name) => switch (name) {
      'tenMinutesBefore' => const [TaskReminder(amount: 10, unit: ReminderUnit.minute)],
      'thirtyMinutesBefore' => const [TaskReminder(amount: 30, unit: ReminderUnit.minute)],
      'oneHourBefore' => const [TaskReminder(amount: 1, unit: ReminderUnit.hour)],
      'oneDayBefore' => const [TaskReminder(amount: 1, unit: ReminderUnit.day)],
      _ => const [],
    };
