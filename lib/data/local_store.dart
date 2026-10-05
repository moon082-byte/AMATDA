import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/task_item.dart';
import '../models/telegram_room.dart';
import 'model_json.dart';

/// 업무방/할 일/설정을 기기 저장소에 보관한다.
/// 웹에서는 브라우저 localStorage, 앱에서는 기기 설정 저장소를 쓴다.
class LocalStore {
  static const _roomsKey = 'rooms_v1';
  static const _tasksKey = 'tasks_v1';
  static const _themeKey = 'theme_mode';
  static const _notifKey = 'notifications_enabled';

  final SharedPreferences _prefs;

  LocalStore._(this._prefs);

  static Future<LocalStore> open() async =>
      LocalStore._(await SharedPreferences.getInstance());

  /// 저장된 값이 없거나 읽을 수 없으면 null을 돌려준다
  List<T>? _readList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return (jsonDecode(raw) as List)
          .map((e) => fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('저장된 $key 데이터를 읽지 못했어요: $e');
      return null;
    }
  }

  List<TelegramRoom>? loadRooms() => _readList(_roomsKey, roomFromJson);
  List<TaskItem>? loadTasks() => _readList(_tasksKey, taskFromJson);

  Future<void> saveData(List<TelegramRoom> rooms, List<TaskItem> tasks) async {
    await _prefs.setString(
        _roomsKey, jsonEncode(rooms.map(roomToJson).toList()));
    await _prefs.setString(
        _tasksKey, jsonEncode(tasks.map(taskToJson).toList()));
  }

  ThemeMode? loadThemeMode() {
    final name = _prefs.getString(_themeKey);
    for (final mode in ThemeMode.values) {
      if (mode.name == name) return mode;
    }
    return null;
  }

  Future<void> saveThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeKey, mode.name);

  bool? loadNotificationsEnabled() => _prefs.getBool(_notifKey);

  Future<void> saveNotificationsEnabled(bool enabled) =>
      _prefs.setBool(_notifKey, enabled);
}
