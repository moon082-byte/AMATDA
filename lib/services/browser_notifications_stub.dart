/// 웹이 아닌 플랫폼용 빈 구현 (앱 버전은 추후 로컬 알림 패키지로 대체)
library;

/// 'granted' | 'denied' | 'default' | 'unsupported'
String notificationPermission() => 'unsupported';

Future<String> requestNotificationPermission() async => 'unsupported';

Future<bool> showBrowserNotification(
  String title,
  String body,
  String tag,
) async =>
    false;

/// 앱 화면이 가려져 있는지(다른 탭/앱으로 전환)
bool isPageHidden() => false;
