import 'date_format.dart';

/// 마감 기한의 긴급도. 배지 색상을 고를 때 쓴다.
enum DueUrgency { none, overdue, today, soon, later }

/// 마감 기한으로부터 D-Day 문자열("D-3", "D-DAY", "D+2")을 계산
String formatDDay(DateTime? dueDate) {
  if (dueDate == null) return '기한 없음';
  final diff = _daysLeft(dueDate);
  if (diff == 0) return 'D-DAY';
  if (diff > 0) return 'D-$diff';
  return 'D+${-diff}';
}

/// 오늘 기준 남은 일수를 긴급도로 분류한다 (3일 이내는 '임박')
DueUrgency dueUrgency(DateTime? dueDate, {bool isDone = false}) {
  if (dueDate == null || isDone) return DueUrgency.none;
  final diff = _daysLeft(dueDate);
  if (diff < 0) return DueUrgency.overdue;
  if (diff == 0) return DueUrgency.today;
  if (diff <= 3) return DueUrgency.soon;
  return DueUrgency.later;
}

int _daysLeft(DateTime dueDate) =>
    dateOnly(dueDate).difference(dateOnly(DateTime.now())).inDays;
