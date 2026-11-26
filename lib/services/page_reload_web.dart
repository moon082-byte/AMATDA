/// 웹 구현: 주소에 버전(?v=)을 붙여 다시 연다.
/// 주소가 달라지므로 텔레그램 미니앱·홈 화면 앱의 캐시된 예전 페이지 대신 새 페이지를 받는다.
library;

import 'dart:js_interop';

@JS('location')
external _Location get _location;

extension type _Location._(JSObject _) implements JSObject {
  external String get pathname;
  external void replace(String url);
}

void reloadToVersion(String version) {
  _location.replace('${_location.pathname}?v=${Uri.encodeQueryComponent(version)}');
}
