import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// 끈질긴 알림 (계정 설정, 기본 켬): 텔레그램 알림을 [✅ 확인]을 누르거나
/// [앱에서 보기]로 앱을 열 때까지 5분마다 최대 3번 더 보낸다 (bot/src/nag.js).
class TelegramNag extends ChangeNotifier {
  final ApiClient? _api;
  bool _enabled = true;
  bool _disposed = false;

  TelegramNag({this._api}) {
    _load();
  }

  bool get enabled => _enabled;

  Future<void> _load() async {
    if (_api == null) return;
    try {
      final res = await _api.get('/api/telegram');
      _set(res['nag'] != false);
    } on ApiException catch (e) {
      debugPrint('끈질긴 알림 설정 확인 실패: $e');
    }
  }

  /// 켜거나 끈다 (모든 기기에 적용). 실패하면 원래대로 돌리고 이유를 돌려준다.
  Future<String?> setEnabled(bool on) async {
    if (_api == null) return '로그인이 필요해요';
    final before = _enabled;
    _set(on);
    try {
      await _api.put('/api/telegram/nag', {'enabled': on});
      return null;
    } on ApiException catch (e) {
      _set(before);
      return e.isOffline ? '인터넷 연결 후 다시 시도해 주세요' : e.message;
    }
  }

  /// 텔레그램 [앱에서 보기]로 앱을 열었으면 그 알림은 더 보내지 않게 한다
  Future<void> acknowledge(String ack) async {
    try {
      await _api?.post('/api/reminders/ack', {'ack': ack});
    } on ApiException catch (e) {
      debugPrint('끈질긴 알림 끄기 실패: $e');
    }
  }

  void _set(bool on) {
    if (_disposed || on == _enabled) return;
    _enabled = on;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
