import 'package:flutter/foundation.dart';
import '../data/local_store.dart';
import 'api_client.dart';

enum PinStatus {
  /// 서버에 PIN 사용 여부를 묻는 중
  checking,

  /// PIN을 켠 계정인데 인터넷이 안 돼 확인할 수 없다
  offline,

  /// PIN 입력이 필요하다
  locked,

  /// 앱을 쓸 수 있다 (PIN을 안 쓰거나 입력을 마쳤다)
  unlocked,
}

/// 2차 비밀번호(4자리 PIN) 상태. 서버 쪽은 bot/src/pin.js.
/// 앱을 열 때마다 새로 만들어져([load]) PIN을 다시 묻는다.
/// 확인·잠금·실패 횟수는 모두 서버가 맡아서 기기 저장소를 지워도 우회할 수 없다.
class PinService extends ChangeNotifier {
  static const offlineMessage = '인터넷 연결 후 입력해 주세요';

  final ApiClient _api;
  final LocalStore _store;

  PinStatus _status = PinStatus.checking;
  bool enabled = false;

  /// 텔레그램이 연결돼 있으면 재설정 코드를 받을 수 있다
  bool telegram = false;

  /// 구글로 막 로그인했으면 코드 없이 새 PIN을 정할 수 있다
  bool freshLogin = false;
  DateTime? lockedUntil;
  int? remaining;
  String? message;

  PinService({required this._api, required this._store});

  PinStatus get status => _status;

  /// 잠겨 있으면 남은 시간 안내 ("… 0:42 뒤에 다시 입력할 수 있어요"), 아니면 null
  String? get lockText {
    final left = lockedUntil?.difference(DateTime.now());
    if (left == null || left.isNegative) return null;
    final s = (left.inSeconds % 60).toString().padLeft(2, '0');
    return '잘못 입력해서 잠겼어요. ${left.inMinutes}:$s 뒤에 다시 입력할 수 있어요';
  }

  /// 앱을 열 때: PIN을 켠 계정이면 잠근다. 서버에 닿지 않으면 마지막으로 알던 설정을 따른다.
  Future<void> load() async {
    try {
      final res = await _api.get('/auth/pin');
      enabled = res['enabled'] == true;
      telegram = res['telegram'] == true;
      freshLogin = res['freshLogin'] == true;
      _lockedFrom(res['lockedUntil']);
      remaining = res['remaining'] as int?;
      await _store.savePinEnabled(enabled);
      _set(enabled ? PinStatus.locked : PinStatus.unlocked);
    } on ApiException catch (e) {
      // 확인할 수 없으면 마지막으로 알던 설정대로: PIN을 켠 계정이면 막는다
      enabled = _store.pinEnabled ?? false;
      message = enabled ? (e.isOffline ? offlineMessage : e.message) : null;
      _set(enabled ? PinStatus.offline : PinStatus.unlocked);
    }
  }

  /// 'PIN을 잊었어요 → 구글로 다시 로그인'을 눌렀다고 기억해 둔다
  Future<void> markResetIntent() => _store.savePinResetPending(true);

  /// 구글로 막 다시 로그인했고 재설정하려던 중이면 true (한 번만)
  bool takeResetIntent() {
    final pending = _store.pinResetPending;
    if (pending) _store.savePinResetPending(false);
    return pending && freshLogin;
  }

  /// 다른 기기에서 PIN을 켜거나 바꿨을 때 다시 입력하게 한다
  void requireAgain() {
    enabled = true;
    _store.savePinEnabled(true);
    _set(PinStatus.locked);
  }

  Future<bool> verify(String pin) async {
    final error = await _call(() => _api.post('/auth/pin/verify', {'pin': pin}));
    if (error == null) _set(PinStatus.unlocked);
    return error == null;
  }

  /// PIN 켜기·바꾸기. 실패하면 안내 문구를 돌려준다.
  Future<String?> setPin(String pin, {String? current}) =>
      _changed(() => _api.put('/auth/pin', {'pin': pin, 'current': ?current}), true);

  Future<String?> disable(String current) =>
      _changed(() => _api.send('DELETE', '/auth/pin', {'current': current}), false);

  Future<String?> sendResetCode() =>
      _call(() => _api.post('/auth/pin/reset/send'));

  /// 텔레그램 코드(또는 구글로 막 로그인한 경우 코드 없이)로 새 PIN을 정한다
  Future<String?> reset(String pin, {String? code}) async {
    final error = await _changed(
        () => _api.post('/auth/pin/reset', {'pin': pin, 'code': ?code}), true);
    if (error == null) _set(PinStatus.unlocked);
    return error;
  }

  Future<String?> _changed(Future<Object?> Function() request, bool on) async {
    final error = await _call(request);
    if (error == null) {
      enabled = on;
      await _store.savePinEnabled(on);
      notifyListeners();
    }
    return error;
  }

  /// 서버 요청 공통 처리: 남은 횟수·잠금 시각을 기억하고 실패 문구를 돌려준다
  Future<String?> _call(Future<Object?> Function() request) async {
    try {
      await request();
      message = null;
      remaining = null;
      lockedUntil = null;
      return null;
    } on ApiException catch (e) {
      message = e.isOffline ? offlineMessage : e.message;
      remaining = e.data['remaining'] as int?;
      _lockedFrom(e.data['lockedUntil']);
      notifyListeners();
      return message;
    }
  }

  void _lockedFrom(Object? epochMs) => lockedUntil = epochMs is int
      ? DateTime.fromMillisecondsSinceEpoch(epochMs)
      : null;

  void _set(PinStatus status) {
    _status = status;
    notifyListeners();
  }
}
