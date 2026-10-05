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

/// 마감 [amount][unit] 전에 알려 주는 할 일 리마인드 (예: 30분 전, 2일 전)
class TaskReminder {
  final int amount;
  final ReminderUnit unit;

  const TaskReminder({required this.amount, required this.unit});

  /// "30분 전", "1주 전"
  String get label => '$amount${unit.label} 전';

  Duration get offset => unit.times(amount);

  /// 마감 일시 기준으로 알림이 울릴 시각
  DateTime fireAt(DateTime dueDate) => dueDate.subtract(offset);

  @override
  bool operator ==(Object other) =>
      other is TaskReminder && other.amount == amount && other.unit == unit;

  @override
  int get hashCode => Object.hash(amount, unit);
}
