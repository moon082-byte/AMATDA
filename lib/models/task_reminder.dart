/// 리마인드 시간 단위
enum ReminderUnit { minute, hour, day, week }

extension ReminderUnitLabel on ReminderUnit {
  String get label => switch (this) {
        ReminderUnit.minute => '분',
        ReminderUnit.hour => '시간',
        ReminderUnit.day => '일',
        ReminderUnit.week => '주',
      };

  Duration times(int amount) => switch (this) {
        ReminderUnit.minute => Duration(minutes: amount),
        ReminderUnit.hour => Duration(hours: amount),
        ReminderUnit.day => Duration(days: amount),
        ReminderUnit.week => Duration(days: amount * 7),
      };
}

/// 마감 [amount][unit] 전에 알려 주는 리마인드 (예: 30분 전, 2일 전).
/// [amount]가 0이면 마감(루틴은 정해 둔 시각) 그 시각에 알린다.
/// 할 일·업무방·루틴 모두 최대 [maxCount]개까지 걸 수 있다.
class TaskReminder {
  static const maxCount = 5;

  final int amount;
  final ReminderUnit unit;

  const TaskReminder({required this.amount, required this.unit});

  /// "30분 전", "1주 전", 0이면 "정시"
  String get label => amount == 0 ? '정시' : '$amount${unit.label} 전';

  Duration get offset => unit.times(amount);

  /// 마감 일시 기준으로 알림이 울릴 시각
  DateTime fireAt(DateTime dueDate) => dueDate.subtract(offset);

  @override
  bool operator ==(Object other) =>
      other is TaskReminder && other.amount == amount && other.unit == unit;

  @override
  int get hashCode => Object.hash(amount, unit);
}

/// 이른 알림(마감에서 먼 것)부터 정렬한다
List<TaskReminder> sortReminders(Iterable<TaskReminder> list) =>
    list.toList()..sort((a, b) => b.offset.compareTo(a.offset));

/// 칩에 쓰는 요약: "30분 전", "1일 전 외 2"
String remindersSummary(List<TaskReminder> list) {
  if (list.isEmpty) return '';
  final first = sortReminders(list).first.label;
  return list.length == 1 ? first : '$first 외 ${list.length - 1}';
}
