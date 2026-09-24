import 'package:flutter/foundation.dart';

/// 전체 알림 On/Off 설정을 관리
class NotificationProvider extends ChangeNotifier {
  bool _enabled = true;

  bool get enabled => _enabled;

  void toggle() {
    _enabled = !_enabled;
    notifyListeners();
  }
}
