/// 할 일 하위의 단계별 세부 체크리스트 항목
class SubTask {
  final String id;
  final String title;
  final bool isDone;

  const SubTask({
    required this.id,
    required this.title,
    this.isDone = false,
  });

  SubTask copyWith({String? title, bool? isDone}) {
    return SubTask(
      id: id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }
}
