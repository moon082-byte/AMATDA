/// 앱 알림함의 알림 하나 (다른 기기에서 바꾼 할 일, 보낸 리마인더)
class InboxItem {
  final String id;

  /// task_added, task_edited, task_deleted, task_done, task_reopened, tasks_changed, reminder
  final String kind;
  final String title;
  final String body;

  /// 누르면 열 항목 (`task:할일id`, `routine:루틴id`). 없으면 null (삭제된 할 일 등)
  final String? target;
  final DateTime createdAt;
  final bool read;

  const InboxItem({
    required this.id,
    required this.kind,
    required this.title,
    this.body = '',
    this.target,
    required this.createdAt,
    this.read = false,
  });

  factory InboxItem.fromJson(Map<String, dynamic> j) => InboxItem(
        id: j['id'] as String,
        kind: j['kind'] as String? ?? '',
        title: j['title'] as String? ?? '',
        body: j['body'] as String? ?? '',
        target: j['target'] as String?,
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (j['createdAt'] as num?)?.toInt() ?? 0),
        read: j['read'] == true,
      );

  InboxItem markedRead() => InboxItem(
      id: id, kind: kind, title: title, body: body, target: target,
      createdAt: createdAt, read: true);
}
