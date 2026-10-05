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
