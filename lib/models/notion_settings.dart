/// 노션 데이터베이스의 속성 하나 (선택·상태 속성은 고를 수 있는 값도)
class NotionProperty {
  final String name;
  final String type;
  final List<String> options;

  const NotionProperty({required this.name, required this.type, this.options = const []});

  factory NotionProperty.fromJson(Map<String, dynamic> j) => NotionProperty(
        name: j['name'] as String,
        type: j['type'] as String,
        options: [for (final o in (j['options'] as List? ?? const [])) o as String],
      );
}

/// [속성 불러오기]로 읽은 노션 데이터베이스
class NotionDb {
  final String id;
  final String name;
  final List<NotionProperty> properties;

  const NotionDb({required this.id, required this.name, required this.properties});

  factory NotionDb.fromJson(Map<String, dynamic> j) => NotionDb(
        id: j['id'] as String,
        name: j['name'] as String? ?? '',
        properties: [
          for (final p in (j['properties'] as List? ?? const []))
            NotionProperty.fromJson(p as Map<String, dynamic>),
        ],
      );

  List<NotionProperty> ofTypes(List<String> types) =>
      properties.where((p) => types.contains(p.type)).toList();

  NotionProperty? byName(String? name) => properties.where((p) => p.name == name).firstOrNull;
}

/// 어떤 데이터베이스에 보내는 매핑인지
enum NotionTarget {
  task('tasks', '할 일'),
  memo('memos', '메모');

  final String table;
  final String label;
  const NotionTarget(this.table, this.label);
}

/// 아맞다 칸 → 노션 속성 이름. 비어 있으면 그 칸은 보내지 않는다.
/// 할 일: 제목·완료(체크박스, 또는 선택·상태의 완료 값/할 일 값)·날짜(마감)·내용
/// 메모: 제목·날짜(작성일)·내용·처음 상태(새로 만들 때만)
class NotionMap {
  String? title;
  String? date;
  String? content;
  String? done;
  String? doneValue;
  String? todoValue;
  String? status;
  String? statusValue;

  NotionMap({
    this.title,
    this.date,
    this.content,
    this.done,
    this.doneValue,
    this.todoValue,
    this.status,
    this.statusValue,
  });

  static NotionMap? fromJson(Object? j) {
    if (j is! Map) return null;
    final done = j['done'] as Map?;
    final status = j['status'] as Map?;
    return NotionMap(
      title: j['title'] as String?,
      date: j['date'] as String?,
      content: j['content'] as String?,
      done: done?['prop'] as String?,
      doneValue: done?['doneValue'] as String?,
      todoValue: done?['todoValue'] as String?,
      status: status?['prop'] as String?,
      statusValue: status?['value'] as String?,
    );
  }

  Map<String, Object?> toJson(NotionTarget target) => {
        'title': title,
        'date': ?date,
        'content': ?content,
        if (target == NotionTarget.task && done != null)
          'done': {'prop': done, 'doneValue': ?doneValue, 'todoValue': ?todoValue},
        if (target == NotionTarget.memo && status != null)
          'status': {'prop': status, 'value': ?statusValue},
      };
}
