import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../config/bot_config.dart';
import '../data/local_store.dart';
import 'api_client.dart';

/// 로그인한 계정의 텔레그램 알림 연결 (휴대폰·PC가 같은 연결을 쓴다).
/// 연결 흐름: 서버에서 연결 코드 받기([prepare]) → t.me/<봇>?start=<코드> 열기 →
/// 사용자가 '시작' → 서버가 계정과 대화방을 묶음 → [refresh]로 확인 → 알림 일정 [sync].
class TelegramLink extends ChangeNotifier {
  static const _codeLifetime = Duration(minutes: 20); // 서버 유효시간(30분)보다 짧게

  final ApiClient? _api;
  final LocalStore? _store;
  final String botUsername;

  String? _name;
  String? _code;
  DateTime? _codeAt;
  bool _pending = false;
  Future<void>? _preparing;
  String? _lastSynced;

  TelegramLink({
    this._api,
    LocalStore? store,
    this.botUsername = kBotUsername,
  })  : _store = store,
        _name = store?.loadTelegramName();

  /// 로그인돼 있고 봇 아이디가 설정돼 있어야 쓸 수 있다
  bool get available => _api != null && botUsername.isNotEmpty;
  bool get linked => _name != null;

  /// 텔레그램을 열었고 '시작'을 기다리는 중
  bool get pending => _pending && !linked;
  String? get chatName => _name;

  bool get _codeFresh =>
      _code != null && DateTime.now().difference(_codeAt!) < _codeLifetime;

  /// 연결 코드를 미리 받아 둔다. 버튼을 누르는 순간 바로 텔레그램을 열어야
  /// 브라우저가 새 창을 막지 않기 때문이다.
  Future<void> prepare() {
    if (!available || linked || _codeFresh) return Future.value();
    return _preparing ??= _fetchCode().whenComplete(() => _preparing = null);
  }

  Future<void> _fetchCode() async {
    try {
      final res = await _api!.post('/api/telegram/code');
      _code = res['code'] as String;
      _codeAt = DateTime.now();
      notifyListeners();
    } on ApiException catch (e) {
      debugPrint('텔레그램 연결 코드 받기 실패: $e');
    }
  }

  /// 텔레그램에서 열 주소. 코드가 아직 없으면 null (잠시 뒤 다시 누르기)
  Uri? startUrl() {
    if (!_codeFresh) {
      prepare();
      return null;
    }
    _pending = true;
    notifyListeners();
    return Uri.parse('https://t.me/$botUsername?start=$_code');
  }

  /// 서버에 연결됐는지 물어본다. 연결 상태가 바뀌면 true.
  Future<bool> refresh() async {
    if (!available) return false;
    try {
      final res = await _api!.get('/api/telegram');
      final name =
          res['linked'] == true ? (res['name'] as String? ?? '') : null;
      if (name == null) prepare();
      if (name == _name) return false;
      _setName(name);
      return true;
    } on ApiException catch (e) {
      debugPrint('텔레그램 연결 확인 실패: $e');
      return false;
    }
  }

  /// 연결을 끊는다 (모든 기기에서 끊긴다)
  Future<void> disconnect() async {
    _setName(null);
    if (!available) return;
    try {
      await _api!.delete('/api/telegram');
    } on ApiException catch (e) {
      debugPrint('텔레그램 연결 해제 요청 실패: $e');
    }
  }

  /// 알림 일정을 봇 서버에 올린다 (바뀐 게 없으면 보내지 않는다)
  Future<void> sync(List<Map<String, Object>> reminders) async {
    if (!available || !linked) return;
    final body = {'reminders': reminders};
    final encoded = jsonEncode(body);
    if (encoded == _lastSynced) return;
    try {
      await _api!.put('/api/reminders', body);
      _lastSynced = encoded;
    } on ApiException catch (e) {
      // 404: 텔레그램에서 /stop 등으로 연결이 끊겼다
      if (e.status == 404) _setName(null);
      debugPrint('텔레그램 알림 일정 업로드 실패: $e');
    }
  }

  void _setName(String? name) {
    _name = name;
    _lastSynced = null; // 새로 연결되면 일정을 다시 올린다
    if (name != null) {
      _pending = false;
      _code = null;
    }
    _store?.saveTelegramName(name);
    notifyListeners();
  }
}
