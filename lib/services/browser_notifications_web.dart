/// 웹 구현: web/notify.js가 만든 window.amatdaNotification을 호출한다
library;

import 'dart:js_interop';

@JS('amatdaNotification')
external _NotificationApi? get _api;

extension type _NotificationApi._(JSObject _) implements JSObject {
  external String permission();
  external JSPromise<JSString> requestPermission();
  external JSPromise<JSBoolean> show(String title, String body, String tag);
  external bool isHidden();
  external bool pushSupported();
  external bool needsHomeScreen();
  external JSPromise<JSString> pushSubscription();
  external JSPromise<JSString> pushSubscribe(String key);
  external JSPromise<JSString> pushUnsubscribe();
}

/// 'granted' | 'denied' | 'default' | 'unsupported'
String notificationPermission() => _api?.permission() ?? 'unsupported';

Future<String> requestNotificationPermission() async {
  final api = _api;
  if (api == null) return 'unsupported';
  try {
    return (await api.requestPermission().toDart).toDart;
  } catch (_) {
    return notificationPermission();
  }
}

Future<bool> showBrowserNotification(
  String title,
  String body,
  String tag,
) async {
  final api = _api;
  if (api == null) return false;
  try {
    return (await api.show(title, body, tag).toDart).toDart;
  } catch (_) {
    return false;
  }
}

/// 앱 화면이 가려져 있는지(다른 탭/앱으로 전환)
bool isPageHidden() => _api?.isHidden() ?? false;

// ---- 시스템 알림 (Web Push) ----

/// 이 브라우저가 푸시를 받을 수 있는지
bool pushSupported() => _api?.pushSupported() ?? false;

/// 아이폰 사파리 탭에서 열어 홈 화면에 추가해야 푸시를 쓸 수 있는지
bool pushNeedsHomeScreen() => _api?.needsHomeScreen() ?? false;

Future<String> _call(JSPromise<JSString> Function(_NotificationApi) f) async {
  final api = _api;
  if (api == null) return 'error:unsupported';
  try {
    return (await f(api).toDart).toDart;
  } catch (e) {
    return 'error:$e';
  }
}

/// 이 기기의 현재 구독 JSON (없으면 빈 문자열)
Future<String> pushSubscription() => _call((api) => api.pushSubscription());

/// 권한을 묻고 구독한다. 구독 JSON 또는 'error:<이유>'
Future<String> pushSubscribe(String key) => _call((api) => api.pushSubscribe(key));

/// 구독을 끊고 끊은 주소를 돌려준다 (없으면 빈 문자열)
Future<String> pushUnsubscribe() => _call((api) => api.pushUnsubscribe());
