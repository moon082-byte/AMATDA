import 'package:flutter/foundation.dart';
import '../models/notion_settings.dart';
import 'api_client.dart';

/// 노션 연동 설정 (서버 쪽은 bot/src/notion_routes.js).
/// 켜 두면 할 일·메모를 저장할 때마다 서버가 사용자가 연결한 노션 데이터베이스에 페이지를 만들거나 고친다.
/// 토큰은 서버에 암호화해 두고 앱에는 돌려받지 않는다 ([hasToken]만 안다).
class NotionService extends ChangeNotifier {
  final ApiClient? _api;
  bool _disposed = false;

  bool enabled = false;
  bool hasToken = false;
  String? taskDb;
  NotionMap? taskMap;
  String? memoDb;
  NotionMap? memoMap;

  /// 노션에 보낼 차례를 기다리는 항목 수, 그중 실패해 다시 시도 중인 수와 마지막 이유
  int waiting = 0;
  int failed = 0;
  String? lastError;
  bool loaded = false;

  NotionService({this._api}) {
    refresh();
  }

  /// 로그인하지 않았으면(테스트·미리보기) 쓸 수 없다
  bool get available => _api != null;

  /// 메모를 노션에 보내는 중인지 (메모 목록의 '노션 저장됨' 표시)
  bool get memoOn => enabled && memoDb != null;
  bool get taskOn => enabled && taskDb != null;

  String? savedDb(NotionTarget t) => t == NotionTarget.task ? taskDb : memoDb;
  NotionMap? savedMap(NotionTarget t) => t == NotionTarget.task ? taskMap : memoMap;

  void _apply(Map<String, dynamic> j) {
    enabled = j['enabled'] == true;
    hasToken = j['hasToken'] == true;
    taskDb = j['taskDb'] as String?;
    taskMap = NotionMap.fromJson(j['taskMap']);
    memoDb = j['memoDb'] as String?;
    memoMap = NotionMap.fromJson(j['memoMap']);
    waiting = (j['waiting'] as num?)?.toInt() ?? 0;
    failed = (j['failed'] as num?)?.toInt() ?? 0;
    lastError = j['lastError'] as String?;
    loaded = true;
    if (!_disposed) notifyListeners();
  }

  Future<void> refresh() async {
    final api = _api;
    if (api == null) return;
    try {
      _apply(await api.get('/api/notion'));
    } on ApiException catch (e) {
      debugPrint('노션 설정을 불러오지 못했어요: ${e.message}');
    }
  }

  static Map<String, Object?> _token(String? token) =>
      {if (token != null && token.trim().isNotEmpty) 'token': token.trim()};

  /// [속성 불러오기]: 데이터베이스 링크(또는 ID)로 이름과 속성 목록을 읽는다. 실패하면 [ApiException]
  Future<NotionDb> inspect({required String db, String? token}) async =>
      NotionDb.fromJson(await _api!.post('/api/notion/inspect', {..._token(token), 'db': db.trim()}));

  /// 저장한다. [targets]에 있는 데이터베이스만 바꾼다 (db가 ''면 연결 해제).
  /// 서버가 매핑을 데이터베이스 속성과 맞춰 보고, 맞지 않으면 [ApiException]을 던진다.
  Future<void> save({
    required bool enabled,
    String? token,
    Map<NotionTarget, ({String db, NotionMap? map})> targets = const {},
  }) async {
    _apply(await _api!.put('/api/notion', {
      'enabled': enabled,
      ..._token(token),
      for (final MapEntry(key: t, value: v) in targets.entries) ...{
        '${t.name}Db': v.db,
        if (v.map != null) '${t.name}Map': v.map!.toJson(t),
      },
    }));
  }

  /// [기존 항목 보내기]: 아직 노션에 없는 항목을 모두 보낸다. 보낼 개수를 돌려준다
  Future<int> backfill(NotionTarget t) async {
    final res = await _api!.post('/api/notion/backfill', {'target': t.table});
    await refresh();
    return (res['count'] as num?)?.toInt() ?? 0;
  }

  /// 연동 해제: 토큰·데이터베이스·매핑을 지운다 (이미 만든 노션 페이지는 그대로)
  Future<void> disconnect() async => _apply(await _api!.delete('/api/notion'));

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
