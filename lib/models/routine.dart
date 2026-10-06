import '../utils/date_format.dart';
import 'task_reminder.dart';

/// 정해 둔 요일마다 같은 시각에 반복하는 습관 (예: 매일 09:00 물 마시기).
/// 날짜별로 완료 여부를 기록하고, 리마인드는 그날의 [hour]:[minute] 기준으로 울린다.
class Routine {
  /// 완료 기록은 최근 이 일수만큼만 보관한다
  static const keepDoneDays = 60;

  final String id;
  final String name;

  /// 반복 요일 ([DateTime.monday]=1 ~ [DateTime.sunday]=7)
  final Set<int> weekdays;
  final int hour;
  final int minute;
  final List<TaskReminder> reminders;

  /// 완료한 날짜들 ("2026-10-06")
  final Set<String> doneDates;
  final DateTime createdAt;

  /// 이 시각 이전의 알림은 울리지 않는다 (만들거나 고친 시각).
  /// 오늘 이미 지난 루틴 시각으로 만들어도 바로 알림이 오지 않게 한다.
  final DateTime remindFrom;

  const Routine({
    required this.id,
    required this.name,
    required this.weekdays,
    this.hour = 9,
    this.minute = 0,
    this.reminders = const [],
    this.doneDates = const {},
    required this.createdAt,
    DateTime? remindFrom,
  }) : remindFrom = remindFrom ?? createdAt;

  bool occursOn(DateTime day) => weekdays.contains(day.weekday);

  /// [day] 날짜의 루틴 시각
  DateTime timeOn(DateTime day) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  bool isDoneOn(DateTime day) => doneDates.contains(dayKey(day));

  /// [at] 회차에 울릴 리마인드 ([remindFrom] 이전 것은 뺀다)
  List<TaskReminder> remindersFor(DateTime at) => [
        for (final r in reminders)
          if (!r.fireAt(at).isBefore(remindFrom)) r,
      ];

  /// [from] 날짜부터 [days]일 동안 루틴이 있는 시각들
  List<DateTime> occurrences(DateTime from, int days) => [
        for (var i = 0; i < days; i++)
          if (occursOn(DateTime(from.year, from.month, from.day + i)))
            timeOn(DateTime(from.year, from.month, from.day + i)),
      ];

  /// [now] 이후(같은 시각 포함) 가장 가까운 루틴 시각. 반복 요일이 없으면 null.
  DateTime? nextOccurrence(DateTime now) {
    if (weekdays.isEmpty) return null;
    return occurrences(now, 8).firstWhere((t) => !t.isBefore(now));
  }

  /// "09:00"
  String get timeLabel => formatTime(DateTime(2000, 1, 1, hour, minute));

  /// "매일", "평일", "주말", "월·수·금"
  String get repeatLabel => repeatLabelOf(weekdays);

  /// [day]의 완료 여부를 바꾼 루틴 (오래된 완료 기록은 정리한다)
  Routine toggledOn(DateTime day) {
    final key = dayKey(day);
    final oldest = dayKey(
      DateTime.now().subtract(const Duration(days: keepDoneDays)),
    );
    final next = {
      for (final d in doneDates)
        if (d.compareTo(oldest) >= 0) d,
    };
    if (!next.remove(key)) next.add(key);
    return _copy(doneDates: next);
  }

  Routine copyWithEdits({
    required String name,
    required Set<int> weekdays,
    required int hour,
    required int minute,
    required List<TaskReminder> reminders,
  }) =>
      _copy(
        name: name,
        weekdays: weekdays,
        hour: hour,
        minute: minute,
        reminders: reminders,
        remindFrom: DateTime.now(),
      );

  Routine _copy({
    String? name,
    Set<int>? weekdays,
    int? hour,
    int? minute,
    List<TaskReminder>? reminders,
    Set<String>? doneDates,
    DateTime? remindFrom,
  }) =>
      Routine(
        id: id,
        name: name ?? this.name,
        weekdays: weekdays ?? this.weekdays,
        hour: hour ?? this.hour,
        minute: minute ?? this.minute,
        reminders: reminders ?? this.reminders,
        doneDates: doneDates ?? this.doneDates,
        createdAt: createdAt,
        remindFrom: remindFrom ?? this.remindFrom,
      );
}

/// 반복 요일 빠른 선택
const everyDay = {1, 2, 3, 4, 5, 6, 7};
const weekDays = {1, 2, 3, 4, 5};
const weekendDays = {6, 7};

bool _sameDays(Set<int> a, Set<int> b) =>
    a.length == b.length && a.containsAll(b);

/// 반복 요일 요약: "매일", "평일", "주말", "월·수·금"
String repeatLabelOf(Set<int> days) {
  if (_sameDays(days, everyDay)) return '매일';
  if (_sameDays(days, weekDays)) return '평일';
  if (_sameDays(days, weekendDays)) return '주말';
  if (days.isEmpty) return '반복 없음';
  return ([...days]..sort()).map((d) => koWeekdays[d - 1]).join('·');
}

/// 날짜별 기록용 키 "2026-10-06"
String dayKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
