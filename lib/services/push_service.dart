import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'api_client.dart';
import 'browser_notifications.dart';

/// 브라우저 푸시 기능 묶음 (테스트에서 가짜로 바꿔 끼울 수 있게)
class PushBridge {
  final bool Function() supported;
  final bool Function() needsHomeScreen;
  final String Function() permission;
  final Future<String> Function() subscription;
  final Future<String> Function(String key) subscribe;
  final Future<String> Function() unsubscribe;

  const PushBridge({
    required this.supported,
    required this.needsHomeScreen,
    required this.permission,
    required this.subscription,
    required this.subscribe,
    required this.unsubscribe,
  });

  static const browser = PushBridge(
    supported: pushSupported,
    needsHomeScreen: pushNeedsHomeScreen,
    permission: notificationPermission,
    subscription: pushSubscription,
    subscribe: pushSubscribe,
    unsubscribe: pushUnsubscribe,
  );
}

/// unavailable: 로그인 안 함 · unsupported: 이 브라우저는 푸시 불가 ·
/// needsHomeScreen: 아이폰 사파리 탭(홈 화면에 추가 필요) · denied: 알림 차단됨
enum PushState { unavailable, unsupported, needsHomeScreen, denied, off, on }

/// 이 기기의 시스템 알림(Web Push) 구독. 켜 두면 앱을 닫아도 봇 서버가 리마인더 시각에 알림을 보낸다.
class PushService extends ChangeNotifier {
  final ApiClient? _api;
  final PushBridge _bridge;
  String? _key;
  bool _on = false;
  bool _busy = false;
  bool _disposed = false;

  PushService({this._api, this._bridge = PushBridge.browser}) {
    _init();
  }

  bool get on => _on;
  bool get busy => _busy;

  PushState get state {
    if (_api == null) return PushState.unavailable;
    if (!_bridge.supported()) {
      return _bridge.needsHomeScreen()
          ? PushState.needsHomeScreen
          : PushState.unsupported;
    }
    if (_on) return PushState.on;
    if (_bridge.permission() == 'denied') return PushState.denied;
    return PushState.off;
  }

  /// 서버 공개키를 미리 받아 둔다 (아이폰은 버튼을 누른 직후에만 권한을 물을 수 있어서).
  /// 이미 구독한 기기면 서버에도 다시 알려 둔다 (다른 계정으로 로그인한 경우 등).
  Future<void> _init() async {
    if (_api == null || !_bridge.supported()) return;
    await _loadKey();
    final current = await _bridge.subscription();
    if (current.isEmpty || current.startsWith('error:')) return;
    if (_bridge.permission() != 'granted') return;
    try {
      await _api.post('/api/push/subscribe', jsonDecode(current));
      _set(on: true);
    } on ApiException catch (e) {
      debugPrint('푸시 구독 다시 알리기 실패: $e');
    }
  }

  Future<String?> _loadKey() async {
    try {
      _key = (await _api!.get('/api/push/key'))['key'] as String?;
    } on ApiException catch (e) {
      debugPrint('푸시 공개키 받기 실패: $e');
    }
    return _key;
  }

  /// 권한을 묻고 이 기기를 구독한다. 실패하면 사용자에게 보여줄 이유를 돌려준다.
  Future<String?> enable() async {
    final api = _api;
    if (api == null) return '로그인이 필요해요';
    _set(busy: true);
    try {
      final key = _key ?? await _loadKey();
      if (key == null) return '서버에 푸시 설정이 아직 없어요';
      final result = await _bridge.subscribe(key);
      if (result.startsWith('error:')) return _errorText(result.substring(6));
      await api.post('/api/push/subscribe', jsonDecode(result));
      _set(on: true);
      return null;
    } on ApiException catch (e) {
      return e.isOffline ? '인터넷 연결 후 다시 시도해 주세요' : e.message;
    } finally {
      _set(busy: false);
    }
  }

  /// 이 기기의 구독을 끊는다 (다른 기기는 그대로)
  Future<void> disable() async {
    _set(busy: true);
    final endpoint = await _bridge.unsubscribe();
    if (endpoint.isNotEmpty && !endpoint.startsWith('error:')) {
      try {
        await _api?.send('DELETE', '/api/push/subscribe', {'endpoint': endpoint});
      } on ApiException catch (e) {
        debugPrint('푸시 구독 삭제 실패: $e');
      }
    }
    _set(on: false, busy: false);
  }

  String _errorText(String reason) => switch (reason) {
        'denied' => '알림이 차단돼 있어요. 브라우저(아이폰은 설정 → 알림 → 아맞다)에서 허용해 주세요',
        'default' => '알림 허용을 선택하지 않았어요. 다시 눌러 주세요',
        _ => '알림을 켜지 못했어요 ($reason)',
      };

  void _set({bool? on, bool? busy}) {
    _on = on ?? _on;
    _busy = busy ?? _busy;
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
