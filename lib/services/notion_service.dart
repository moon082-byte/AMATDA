import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// 노션 연동 설정 (서버 쪽은 bot/src/notion_routes.js).
/// 켜 두면 메모를 저장할 때마다 서버가 노션 메모 DB(1_Inbox)에 페이지를 만들거나 고친다.
/// 토큰은 서버에 암호화해 두고 앱에는 돌려받지 않는다 ([hasToken]만 안다).
class NotionService extends ChangeNotifier {
  final ApiClient? _api;
  bool _disposed = false;

  bool enabled = false;
  bool hasToken = false;
  String? memoDb;
  bool loaded = false;

  NotionService({this._api}) {
    refresh();
  }

  /// 로그인하지 않았으면(테스트·미리보기) 쓸 수 없다
  bool get available => _api != null;

  void _apply(Map<String, dynamic> j) {
    enabled = j['enabled'] == true;
    hasToken = j['hasToken'] == true;
    memoDb = j['memoDb'] as String?;
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

  /// 저장한다. 켤 때는 서버가 메모 DB를 확인하고, 문제가 있으면 [ApiException]을 던진다.
  /// [token]·[memoDb]가 비어 있으면 저장된 값을 그대로 쓴다.
  Future<void> save({required bool enabled, String? token, String? memoDb}) async {
    _apply(await _api!.put('/api/notion', {
      'enabled': enabled,
      if (token != null && token.trim().isNotEmpty) 'token': token.trim(),
      if (memoDb != null && memoDb.trim().isNotEmpty) 'memoDb': memoDb.trim(),
    }));
  }

  /// [연결 확인]: 성공하면 안내 문구, 실패하면 [ApiException]
  Future<String> check({String? token, String? memoDb}) async {
    final res = await _api!.post('/api/notion/check', {
      if (token != null && token.trim().isNotEmpty) 'token': token.trim(),
      if (memoDb != null && memoDb.trim().isNotEmpty) 'memoDb': memoDb.trim(),
    });
    return res['message'] as String? ?? '연결할 수 있어요';
  }

  /// 연동 해제: 토큰과 DB 설정을 지운다 (이미 만든 노션 페이지는 그대로)
  Future<void> disconnect() async => _apply(await _api!.delete('/api/notion'));

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
