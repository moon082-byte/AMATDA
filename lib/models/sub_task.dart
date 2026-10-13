/// 할 일 하위의 단계별 세부 체크리스트 항목.
/// [remindAt]은 직접 고른 리마인더 알림 시각들이다.
class SubTask {
  final String id;
  final String title;
  final bool isDone;
  final List<DateTime> remindAt;

  const SubTask({
    required this.id,
    required this.title,
    this.isDone = false,
    this.remindAt = const [],
  });

  SubTask copyWith({String? title, bool? isDone, List<DateTime>? remindAt}) {
    return SubTask(
      id: id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
      remindAt: remindAt ?? this.remindAt,
    );
  }
}
