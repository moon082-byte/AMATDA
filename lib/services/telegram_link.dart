import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/bot_config.dart';
import '../data/local_store.dart';

/// 텔레그램 알림봇 연결 상태와 봇 서버 통신을 맡는다.
/// 연결 흐름: 무작위 코드 생성 → t.me/<봇>?start=<코드> 열기 → 사용자가 '시작' →
/// 봇 서버가 코드와 대화방을 묶음 → 앱이 [refresh]로 연결 확인 → 알림 일정 [sync].
class TelegramLink extends ChangeNotifier {
  final LocalStore? _store;
  final http.Client _client;
  final String apiUrl;
  final String botUsername;

  String? _code;
  String? _name;
  String? _lastSynced;

  TelegramLink({
    LocalStore? store,
    http.Client? client,
    this.apiUrl = kBotApiUrl,
    this.botUsername = kBotUsername,
  })  : _store = store,
        _client = client ?? http.Client(),
        _code = store?.loadTelegramCode(),
        _name = store?.loadTelegramName();

  /// 봇 서버 주소와 봇 아이디가 설정돼 있어야 쓸 수 있다
  bool get available => apiUrl.isNotEmpty && botUsername.isNotEmpty;
  bool get linked => _name != null;
  bool get pending => _code != null && !linked;
  String? get chatName => _name;

  /// 텔레그램에서 열 주소. 연결 코드가 없으면 새로 만든다.
  Uri startUrl() {
    _code ??= _newCode();
    _save();
    return Uri.parse('https://t.me/$botUsername?start=$_code');
  }

  /// 봇 서버에 연결됐는지 물어본다. 연결 상태가 바뀌면 true.
  Future<bool> refresh() async {
    final code = _code;
    if (!available || code == null) return false;
    try {
      final res = await _client.get(_uri('/api/link/$code'));
      if (res.statusCode != 200) return false;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      final name = body['linked'] == true ? (body['name'] as String? ?? '') : null;
      if (name == _name) return false;
      _name = name;
      _lastSynced = null; // 새로 연결되면 일정을 다시 올린다
      _save();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('텔레그램 연결 확인 실패: $e');
      return false;
    }
  }

  /// 연결을 끊는다. 다음에 연결할 때는 새 코드를 쓴다.
  Future<void> disconnect() async {
    final code = _code;
    _code = null;
    _name = null;
    _lastSynced = null;
    _save();
    notifyListeners();
    if (!available || code == null) return;
    try {
      await _client.delete(_uri('/api/link/$code'));
    } catch (e) {
      debugPrint('텔레그램 연결 해제 요청 실패: $e');
    }
  }

  /// 알림 일정을 봇 서버에 올린다 (바뀐 게 없으면 보내지 않는다)
  Future<void> sync(List<Map<String, Object>> reminders) async {
    final code = _code;
    if (!available || !linked || code == null) return;
    final body = jsonEncode({'reminders': reminders});
    if (body == _lastSynced) return;
    try {
      final res = await _client.put(
        _uri('/api/reminders/$code'),
        headers: {'Content-Type': 'application/json'},
        body: body,
      );
      if (res.statusCode == 200) {
        _lastSynced = body;
      } else if (res.statusCode == 404) {
        // 텔레그램에서 /stop 등으로 연결이 끊겼다
        _name = null;
        _save();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('텔레그램 알림 일정 업로드 실패: $e');
    }
  }

  Uri _uri(String path) => Uri.parse('$apiUrl$path');

  void _save() => _store?.saveTelegram(code: _code, name: _name);

  static String _newCode() {
    const chars =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    final rand = Random.secure();
    return List.generate(32, (_) => chars[rand.nextInt(chars.length)]).join();
  }
}
