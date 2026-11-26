import 'package:flutter/widgets.dart';
import '../models/notion_settings.dart';
import 'api_client.dart';
import 'notion_service.dart';

/// 노션 설정 화면에서 데이터베이스 하나(할일용 또는 메모용)를 고치는 중인 상태:
/// 링크 입력칸, [속성 불러오기]로 읽은 속성 목록, 고른 매핑.
class NotionDbDraft extends ChangeNotifier {
  final NotionTarget target;
  final link = TextEditingController();
  final String? _saved;

  NotionDb? db;
  NotionMap map;
  bool loading = false;
  String? error;

  /// 링크나 매핑을 손댔는지 (손대지 않았으면 저장할 때 보내지 않는다)
  bool touched = false;

  NotionDbDraft(this.target, {String? savedDb, NotionMap? savedMap})
      : _saved = savedDb,
        map = savedMap ?? NotionMap() {
    link.text = savedDb ?? '';
  }

  /// 할일용·메모용 두 칸을 저장된 설정으로 만든다 ([load]면 연결된 데이터베이스의 속성도 읽는다)
  static List<NotionDbDraft> all(NotionService s, {bool load = false}) {
    final drafts = [
      for (final t in NotionTarget.values) NotionDbDraft(t, savedDb: s.savedDb(t), savedMap: s.savedMap(t)),
    ];
    if (load && s.hasToken) {
      for (final d in drafts.where((d) => d.connected)) {
        d.load(s);
      }
    }
    return drafts;
  }

  bool get connected => _saved != null;

  void edit(void Function(NotionMap m) change) {
    change(map);
    touched = true;
    notifyListeners();
  }

  /// 링크를 바꾸면 예전에 읽은 속성은 버린다
  void linkChanged() {
    touched = true;
    db = null;
    error = null;
    notifyListeners();
  }

  /// [속성 불러오기]. 제목 속성은 하나뿐이라 바로 고른다
  Future<void> load(NotionService service, {String? token}) async {
    if (link.text.trim().isEmpty) return;
    loading = true;
    error = null;
    notifyListeners();
    try {
      final loaded = db = await service.inspect(db: link.text, token: token);
      map.title ??= loaded.ofTypes(const ['title']).firstOrNull?.name;
      // 데이터베이스에 없는 속성을 골라 둔 것은 지운다
      bool has(String? name) => name == null || loaded.byName(name) != null;
      if (!has(map.title)) map.title = loaded.ofTypes(const ['title']).firstOrNull?.name;
      if (!has(map.date)) map.date = null;
      if (!has(map.content)) map.content = null;
      if (!has(map.done)) map.done = map.doneValue = map.todoValue = null;
      if (!has(map.status)) map.status = map.statusValue = null;
    } on ApiException catch (e) {
      error = e.isOffline ? '인터넷 연결 후 다시 시도해 주세요' : e.message;
    } finally {
      loading = false;
      notifyListeners();
    }
  }

  /// 저장할 값. 보낼 게 없으면 null, 연결을 끊으면 db가 ''.
  /// 아직 보낼 수 없으면(속성을 안 불러왔거나 제목을 안 골랐으면) 이유를 [StateError]로 알린다
  ({String db, NotionMap? map})? payload() {
    if (!touched) return null;
    if (link.text.trim().isEmpty) return connected ? (db: '', map: null) : null;
    final loaded = db;
    if (loaded == null) throw StateError('${target.label} 데이터베이스의 [속성 불러오기]를 먼저 눌러 주세요');
    if (map.title == null) throw StateError('${target.label} 데이터베이스에서 제목으로 쓸 속성을 골라 주세요');
    return (db: loaded.id, map: map);
  }

  @override
  void dispose() {
    link.dispose();
    super.dispose();
  }
}
