part of 'local_store.dart';

/// 로그인·동기화·텔레그램 연결 상태 저장
extension LocalStoreAccount on LocalStore {
  static const _sessionKey = 'session_v1';
  static const _syncKey = 'sync_v1';
  static const _tgNameKey = 'telegram_chat';
  static const _importKey = 'legacy_import_done';

  /// 로그인 토큰과 사용자 정보 (기기 단위). 없으면 null.
  ({String token, Map<String, dynamic> user})? loadSession() {
    final raw = _prefs.getString(_sessionKey);
    if (raw == null) return null;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return (token: j['token'] as String, user: j['user'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> saveSession(String token, Map<String, dynamic> user) =>
      _prefs.setString(_sessionKey, jsonEncode({'token': token, 'user': user}));

  Future<void> clearSession() => _prefs.remove(_sessionKey);

  /// 동기화 상태: 마지막으로 받은 순번과 서버에 있는 것으로 확인된 항목들(JSON)
  ({int cursor, String? shadow}) loadSyncState() {
    final raw = _prefs.getString(_key(_syncKey));
    if (raw == null) return (cursor: 0, shadow: null);
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      return (cursor: j['cursor'] as int, shadow: j['shadow'] as String);
    } catch (_) {
      return (cursor: 0, shadow: null);
    }
  }

  Future<void> saveSyncState(int cursor, String shadow) => _prefs.setString(
      _key(_syncKey), jsonEncode({'cursor': cursor, 'shadow': shadow}));

  /// 연결된 텔레그램 이름 (계정 단위, 앱을 다시 열 때 바로 보여주기용)
  String? loadTelegramName() => _prefs.getString(_key(_tgNameKey));

  Future<void> saveTelegramName(String? name) => name == null
      ? _prefs.remove(_key(_tgNameKey))
      : _prefs.setString(_key(_tgNameKey), name);

  /// 이 기기의 예전 데이터를 계정으로 가져올지 이미 물어봤는지 (기기 단위)
  bool get legacyImportAsked => _prefs.getBool(_importKey) ?? false;

  Future<void> markLegacyImportAsked() => _prefs.setBool(_importKey, true);
}
