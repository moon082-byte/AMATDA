part of 'routine.dart';

// 반복 요일·날짜 키 도우미 (routine.dart를 가져오면 함께 쓸 수 있다)

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
