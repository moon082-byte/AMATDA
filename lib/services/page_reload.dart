/// 페이지를 최신 버전으로 다시 불러오기(웹). 웹이 아닌 플랫폼에서는 아무 동작도 하지 않는다.
library;

export 'page_reload_stub.dart' if (dart.library.js_interop) 'page_reload_web.dart';
