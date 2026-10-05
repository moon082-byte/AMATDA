/// 브라우저 알림(웹) 기능. 웹이 아닌 플랫폼에서는 아무 동작도 하지 않는다.
library;

export 'browser_notifications_stub.dart'
    if (dart.library.js_interop) 'browser_notifications_web.dart';
