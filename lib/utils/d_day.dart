/// 마감 기한으로부터 D-Day 문자열("D-3", "D-DAY", "D+2")을 계산
String formatDDay(DateTime? dueDate) {
  if (dueDate == null) return '기한 없음';

  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final due = DateTime(dueDate.year, dueDate.month, dueDate.day);
  final diff = due.difference(today).inDays;

  if (diff == 0) return 'D-DAY';
  if (diff > 0) return 'D-$diff';
  return 'D+${-diff}';
}
