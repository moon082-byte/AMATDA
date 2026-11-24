part of 'model_json.dart';

// 메모 ↔ JSON ('notion'은 서버가 적어 주는 노션 반영 결과, 앱은 그대로 보존한다)

Map<String, Object?> memoToJson(Memo m) => {
      'id': m.id,
      'title': m.title,
      'content': m.content,
      'createdAt': _date(m.createdAt),
      'updatedAt': _date(m.updatedAt),
      if (m.notion case final n?) 'notion': n.toJson(),
    };

Memo memoFromJson(Map<String, dynamic> j) {
  final created = _parseDate(j['createdAt']) ?? DateTime.now();
  return Memo(
    id: j['id'] as String,
    title: j['title'] as String? ?? '',
    content: j['content'] as String? ?? '',
    createdAt: created,
    updatedAt: _parseDate(j['updatedAt']) ?? created,
    notion: MemoNotion.fromJson(j['notion']),
  );
}
