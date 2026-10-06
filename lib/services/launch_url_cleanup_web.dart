/// 웹 구현: 페이지를 다시 불러오지 않고 주소창 주소만 바꾼다 (history.replaceState)
library;

import 'dart:js_interop';

@JS('history')
external _History get _history;

extension type _History._(JSObject _) implements JSObject {
  external void replaceState(JSAny? data, String unused, String url);
}

void replaceBrowserUrl(String url) {
  try {
    _history.replaceState(null, '', url);
  } catch (_) {
    // 주소를 못 바꿔도 앱 동작에는 지장이 없다
  }
}
