/// 브라우저 주소창 주소 바꾸기(웹). 웹이 아닌 플랫폼에서는 아무 동작도 하지 않는다.
library;

export 'launch_url_cleanup_stub.dart'
    if (dart.library.js_interop) 'launch_url_cleanup_web.dart';
