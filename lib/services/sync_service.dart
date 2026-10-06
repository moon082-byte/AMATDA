import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/local_store.dart';
import '../data/sync_records.dart';
import '../data/sync_shadow.dart';
import '../providers/room_provider.dart';
import '../providers/routine_provider.dart';
import 'api_client.dart';

/// 기기 간 데이터 동기화 (서버 쪽은 bot/src/sync.js).
///
/// [_shadow]는 "서버에 이렇게 저장돼 있다"고 마지막으로 확인한 행들이다.
/// 지금 앱 데이터와 비교해 다른 행만 올리고, 다른 기기가 바꾼 행은 받아서 앱에 반영한다.
/// 같은 항목을 두 기기에서 고치면 서버에 나중에 도착한 쪽이 이긴다.
class SyncService extends ChangeNotifier {
  static const _maxPush = 500; // 서버 MAX_SYNC_ROWS와 같음

  final ApiClient _api;
  final LocalStore _store;
  final RoomProvider _rooms;
  final RoutineProvider _routines;

  late int _cursor;
  late RecordSet _shadow;
  bool _running = false;
  bool _again = false;
  bool _applying = false;
  Timer? _debounce;
  Timer? _ticker;
  final _firstSync = Completer<void>();

  DateTime? lastSyncedAt;
  String? error;

  SyncService({
    required this._api,
    required LocalStore store,
    required this._rooms,
    required this._routines,
  }) : _store = store {
    final saved = store.loadSyncState();
    final shadow = decodeRecordSet(saved.shadow);
    // 저장된 상태가 없거나 깨졌으면 처음부터 다시 받는다
    _cursor = shadow == null ? 0 : saved.cursor;
    _shadow = shadow ?? emptyRecordSet();
  }

  /// 처음 한 번 서버와 맞춘 뒤 완료된다
  Future<void> get firstSync => _firstSync.future;

  void start() {
    _rooms.addListener(_schedule);
    _routines.addListener(_schedule);
    _ticker = Timer.periodic(const Duration(seconds: 30), (_) => syncNow());
    syncNow();
  }

  @override
  void dispose() {
    _rooms.removeListener(_schedule);
    _routines.removeListener(_schedule);
    _debounce?.cancel();
    _ticker?.cancel();
    super.dispose();
  }

  /// 앱 데이터가 바뀌면 2초 뒤에 (연속 변경은 한 번에) 올린다
  void _schedule() {
    if (_applying) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), syncNow);
  }

  Future<void> syncNow() async {
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _round();
      } while (_again);
      lastSyncedAt = DateTime.now();
      error = null;
      if (!_firstSync.isCompleted) _firstSync.complete();
    } on ApiException catch (e) {
      error = e.message;
    } finally {
      _running = false;
      notifyListeners();
    }
  }

  Future<void> _round() async {
    final pushed = diffRecords(_currentRecords(), _shadow, max: _maxPush);
    final res = await _api.post('/api/sync', {
      'since': _cursor,
      'changes': {
        for (final t in syncTables)
          t: [for (final r in pushed[t]!) r.toJson()],
      },
    });
    for (final t in syncTables) {
      for (final r in pushed[t]!) {
        r.deleted ? _shadow[t]!.remove(r.id) : _shadow[t]![r.id] = r;
      }
    }
    final pulled = emptyRecordSet();
    final remote = res['changes'] as Map<String, dynamic>;
    for (final t in syncTables) {
      for (final j in (remote[t] as List? ?? const [])) {
        final r = SyncRecord.fromJson(j as Map<String, dynamic>);
        r.deleted ? _shadow[t]!.remove(r.id) : _shadow[t]![r.id] = r;
        // 방금 올린 것이 그대로 돌아온 경우는 건너뛴다 (그 사이 고친 내용을 덮지 않게)
        final mine = pushed[t]!.where((p) => p.id == r.id).firstOrNull;
        if (mine == null || !mine.sameAs(r)) pulled[t]![r.id] = r;
      }
    }
    _cursor = res['version'] as int;
    if (pulled.values.any((m) => m.isNotEmpty)) _apply(pulled);
    await _store.saveSyncState(_cursor, encodeRecordSet(_shadow));
    final pushedCount = pushed.values.fold(0, (n, l) => n + l.length);
    if (res['more'] == true || pushedCount >= _maxPush) _again = true;
  }

  RecordSet _currentRecords() =>
      toRecords(_rooms.rooms, _rooms.tasks, _routines.routines);

  /// 다른 기기에서 받은 행을 지금 앱 데이터에 덮어 다시 만든다
  void _apply(RecordSet pulled) {
    final current = _currentRecords();
    for (final t in syncTables) {
      for (final r in pulled[t]!.values) {
        r.deleted ? current[t]!.remove(r.id) : current[t]![r.id] = r;
      }
    }
    final data = fromRecords(current);
    _applying = true;
    try {
      _rooms.replaceAll(data.rooms, data.tasks);
      _routines.replaceAll(data.routines);
    } finally {
      _applying = false;
    }
  }
}
