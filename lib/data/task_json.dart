part of 'model_json.dart';

// 할 일·세부 항목 ↔ JSON
// 리마인더는 직접 고른 알림 시각 목록('remindAt')으로 저장한다.
// 예전 형식('reminders': 마감 N단위 전)은 읽을 때 실제 알림 시각(마감 − N)으로 바꾼다.

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
        for (final s in t.subTasks) {'id': s.id, ...subTaskToJson(s)},
      ],
      'notes': [
        for (final n in t.notes)
          {'id': n.id, 'content': n.content, 'createdAt': _date(n.createdAt)},
      ],
      'remindAt': _remindAtToJson(t.remindAt),
      if (t.project case final p?) 'project': p.toJson(),
    };

TaskItem taskFromJson(Map<String, dynamic> j) {
  final due = _parseDate(j['dueDate']);
  return TaskItem(
    id: j['id'] as String,
    title: j['title'] as String,
    description: j['description'] as String?,
    isDone: (j['isDone'] as bool?) ?? false,
    dueDate: due,
    completedAt: _parseDate(j['completedAt']),
    priority:
        _enumByName(TaskPriority.values, j['priority'], TaskPriority.medium),
    roomId: j['roomId'] as String?,
    createdAt: _parseDate(j['createdAt']) ?? DateTime.now(),
    subTasks: [
      for (final s in (j['subTasks'] as List? ?? const []))
        SubTask(
          id: s['id'] as String,
          title: s['title'] as String,
          isDone: (s['isDone'] as bool?) ?? false,
          remindAt: _remindAtFromJson(s, due),
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
    remindAt: _remindAtFromJson(j, due),
    project: ProjectLink.fromJson(j['project']),
  );
}

/// 세부 항목 내용 (id 제외, 서버 동기화에도 같은 모양을 쓴다)
Map<String, Object?> subTaskToJson(SubTask s) => {
      'title': s.title,
      'isDone': s.isDone,
      if (s.remindAt.isNotEmpty) 'remindAt': _remindAtToJson(s.remindAt),
    };

List<String> _remindAtToJson(List<DateTime> list) =>
    [for (final t in list) t.toIso8601String()];

/// 'remindAt'이 있으면 그대로, 없으면 예전 'reminders'/'reminder'를 마감 기준 시각으로 바꾼다
List<DateTime> _remindAtFromJson(Map<dynamic, dynamic> j, DateTime? due) {
  final times = j['remindAt'];
  if (times is List) {
    return normalizeRemindAt([for (final t in times) ?_parseDate(t)]);
  }
  if (due == null) return const [];
  final legacy =
      _remindersFromJson(j['reminders']) ?? [?_reminderFromJson(j['reminder'])];
  return normalizeRemindAt([for (final r in legacy) r.fireAt(due)]);
}
