{{flutter_js}}
{{flutter_build_config}}

// Flutter 기본 서비스 워커(지원 종료 예정, 스스로 등록 해제함)는 쓰지 않는다.
// 알림용 서비스 워커(notify_sw.js)는 notify.js에서 따로 등록한다.
_flutter.loader.load();
