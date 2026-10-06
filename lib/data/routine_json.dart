part of 'model_json.dart';

// 루틴 ↔ JSON

Map<String, Object?> routineToJson(Routine r) => {
      'id': r.id,
      'name': r.name,
      'weekdays': [...r.weekdays]..sort(),
      'hour': r.hour,
      'minute': r.minute,
      'reminders': _remindersToJson(r.reminders),
      'doneDates': [...r.doneDates]..sort(),
      'createdAt': _date(r.createdAt),
      'remindFrom': _date(r.remindFrom),
    };

Routine routineFromJson(Map<String, dynamic> j) => Routine(
      id: j['id'] as String,
      name: j['name'] as String,
      weekdays: {
        for (final d in (j['weekdays'] as List? ?? const []))
          if (d is int && d >= 1 && d <= 7) d,
      },
      hour: ((j['hour'] as int?) ?? 9).clamp(0, 23),
      minute: ((j['minute'] as int?) ?? 0).clamp(0, 59),
      reminders: _remindersFromJson(j['reminders']) ?? const [],
      doneDates: {for (final d in (j['doneDates'] as List? ?? const [])) '$d'},
      createdAt: _parseDate(j['createdAt']) ?? DateTime.now(),
      remindFrom: _parseDate(j['remindFrom']),
    );
