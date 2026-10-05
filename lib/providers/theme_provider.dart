import 'package:flutter/material.dart';
import '../data/local_store.dart';

/// 앱 전체 다크/라이트/시스템 테마 모드를 관리
class ThemeProvider extends ChangeNotifier {
  final LocalStore? _store;
  ThemeMode _themeMode;

  ThemeProvider({LocalStore? store})
      : _store = store,
        _themeMode = store?.loadThemeMode() ?? ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _store?.saveThemeMode(mode);
    notifyListeners();
  }
}
