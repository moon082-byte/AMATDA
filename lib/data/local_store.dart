import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/routine.dart';
import '../models/task_item.dart';
import '../models/telegram_room.dart';
import 'model_json.dart';

part 'local_store_account.dart';

/// 업무방/할 일/루틴/설정을 기기 저장소에 보관한다.
/// 웹에서는 브라우저 localStorage, 앱에서는 기기 설정 저장소를 쓴다.
///
/// 데이터(업무방·할 일·루틴·동기화 상태)는 계정마다 따로 저장한다([forUser]).
/// 계정 없이 연 저장소의 데이터는 로그인 도입 전 이 기기에 쌓인 예전 데이터다.
/// 테마·알림 설정과 로그인 정보는 기기 단위로 저장한다.
class LocalStore {
  static const _roomsKey = 'rooms_v1';
  static const _tasksKey = 'tasks_v1';
  static const _routinesKey = 'routines_v1';
  static const _themeKey = 'theme_mode';
  static const _notifKey = 'notifications_enabled';
  static const _firedKey = 'fired_reminders';

  final SharedPreferences _prefs;

  /// 계정 데이터 키 앞에 붙는 값 ('' 이면 예전 기기 데이터)
  final String _scope;

  LocalStore._(this._prefs, [this._scope = '']);

  static Future<LocalStore> open() async =>
      LocalStore._(await SharedPreferences.getInstance());

  /// [userId] 계정의 데이터를 따로 보관하는 저장소
  LocalStore forUser(String userId) => LocalStore._(_prefs, 'u:$userId:');

  String _key(String name) => '$_scope$name';

  /// 저장된 값이 없거나 읽을 수 없으면 null을 돌려준다
  List<T>? _readList<T>(String key, T Function(Map<String, dynamic>) fromJson) {
    final raw = _prefs.getString(_key(key));
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
        _key(_roomsKey), jsonEncode(rooms.map(roomToJson).toList()));
    await _prefs.setString(
        _key(_tasksKey), jsonEncode(tasks.map(taskToJson).toList()));
  }

  List<Routine>? loadRoutines() => _readList(_routinesKey, routineFromJson);

  Future<void> saveRoutines(List<Routine> routines) => _prefs.setString(
      _key(_routinesKey), jsonEncode(routines.map(routineToJson).toList()));

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

  /// 이미 울린 리마인드 목록 (같은 알림이 두 번 울리지 않게)
  Set<String> loadFiredReminders() =>
      (_prefs.getStringList(_firedKey) ?? const []).toSet();

  Future<void> saveFiredReminders(Set<String> keys) {
    // 오래된 기록이 끝없이 쌓이지 않도록 최근 300개만 남긴다
    final list = keys.toList();
    final recent = list.length > 300 ? list.sublist(list.length - 300) : list;
    return _prefs.setStringList(_firedKey, recent);
  }
}
