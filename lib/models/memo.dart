/// 노션에 반영한 결과 (서버가 메모에 적어 내려준다. 앱은 읽기만 하고 그대로 보존한다)
class MemoNotion {
  final String? pageId;

  /// 노션에 반영한 메모 내용의 수정 시각 (메모의 수정 시각과 같으면 최신 내용이 반영된 것)
  final String? syncedFor;
  final String? error;
  final String? errorFor;

  const MemoNotion({this.pageId, this.syncedFor, this.error, this.errorFor});

  static MemoNotion? fromJson(Object? j) => j is Map
      ? MemoNotion(
          pageId: j['pageId'] as String?,
          syncedFor: j['syncedFor'] as String?,
          error: j['error'] as String?,
          errorFor: j['errorFor'] as String?,
        )
      : null;

  Map<String, Object?> toJson() =>
      {'pageId': pageId, 'syncedFor': syncedFor, 'error': error, 'errorFor': errorFor};
}

/// 메모 목록에 보여줄 노션 반영 상태
enum MemoNotionState { none, pending, saved, failed }

class Memo {
  final String id;
  final String title;
  final String content;
  final DateTime createdAt;
  final DateTime updatedAt;
  final MemoNotion? notion;

  const Memo({
    required this.id,
    this.title = '',
    this.content = '',
    required this.createdAt,
    required this.updatedAt,
    this.notion,
  });

  /// 목록에 보일 제목 (제목이 없으면 내용 첫 줄)
  String get displayTitle {
    if (title.trim().isNotEmpty) return title.trim();
    final first = content.trim().split('\n').first.trim();
    return first.isEmpty ? '제목 없음' : first;
  }

  /// 제목·내용을 바꾸고 수정 시각을 새로 찍는다 (노션 반영 결과는 그대로 두고 서버가 갱신한다)
  Memo edited({required String title, required String content}) => Memo(
        id: id,
        title: title,
        content: content,
        createdAt: createdAt,
        updatedAt: DateTime.now(),
        notion: notion,
      );

  /// [notionOn]: 이 계정이 노션 연동을 켰는지
  MemoNotionState notionState({required bool notionOn}) {
    final n = notion;
    final version = updatedAt.toIso8601String();
    if (n?.error != null && n?.errorFor == version) return MemoNotionState.failed;
    if (n?.syncedFor == version && n?.pageId != null) return MemoNotionState.saved;
    return notionOn ? MemoNotionState.pending : MemoNotionState.none;
  }
}
