import 'package:flutter/foundation.dart';
import '../data/local_store.dart';

/// 전체 알림 On/Off 설정을 관리
class NotificationProvider extends ChangeNotifier {
  final LocalStore? _store;
  bool _enabled;

  NotificationProvider({LocalStore? store})
      : _store = store,
        _enabled = store?.loadNotificationsEnabled() ?? true;

  bool get enabled => _enabled;

  void toggle() {
    _enabled = !_enabled;
    _store?.saveNotificationsEnabled(_enabled);
    notifyListeners();
  }
}
