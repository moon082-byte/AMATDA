/// 한국어 날짜 표기 유틸 (intl 없이 앱에서 쓰는 형식만 제공)
const koWeekdays = ['월', '화', '수', '목', '금', '토', '일'];

/// 날짜의 한 글자 요일 ("월" ~ "일")
String koWeekdayShort(DateTime date) => koWeekdays[date.weekday - 1];

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

bool isSameDate(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;

String _two(int n) => n.toString().padLeft(2, '0');

bool _hasTime(DateTime d) => d.hour != 0 || d.minute != 0;

String formatTime(DateTime d) => '${_two(d.hour)}:${_two(d.minute)}';

/// "9월 24일 목요일"
String formatFullDate(DateTime d) =>
    '${d.month}월 ${d.day}일 ${koWeekdayShort(d)}요일';

/// "9월 24일 (목)"
String formatDateWithWeekday(DateTime d) =>
    '${d.month}월 ${d.day}일 (${koWeekdayShort(d)})';

/// "2026년 9월"
String formatYearMonth(DateTime d) => '${d.year}년 ${d.month}월';

/// 오늘/내일/어제는 상대 표현으로, 그 외에는 날짜로 표기한다.
/// 예) "오늘 18:00", "내일", "9월 30일 (화) 12:00"
String formatRelativeDateTime(DateTime d) {
  final diff = dateOnly(d).difference(dateOnly(DateTime.now())).inDays;
  final String day;
  if (diff == 0) {
    day = '오늘';
  } else if (diff == 1) {
    day = '내일';
  } else if (diff == -1) {
    day = '어제';
  } else {
    day = formatDateWithWeekday(d);
  }
  return _hasTime(d) ? '$day ${formatTime(d)}' : day;
}

/// 아카이브 묶음 제목용: "오늘", "어제", "9월 19일 (토)"
String formatDayGroup(DateTime d) {
  final diff = dateOnly(DateTime.now()).difference(dateOnly(d)).inDays;
  if (diff == 0) return '오늘';
  if (diff == 1) return '어제';
  return formatDateWithWeekday(d);
}
