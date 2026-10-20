import 'dart:async';
import 'package:flutter/widgets.dart';
import '../data/local_store.dart';
import '../models/inbox_item.dart';
import 'api_client.dart';

/// 앱 알림함 (다른 기기에서 바꾼 할 일, 보낸 리마인더). 서버에 쌓인 것을 2분마다·앱으로 돌아올 때 받아 온다.
class InboxService extends ChangeNotifier with WidgetsBindingObserver {
  static const refreshEvery = Duration(minutes: 2);

  final ApiClient? _api;

  /// 이 기기 번호: 이 기기에서 바꾼 것은 이 기기 알림함에 보이지 않는다
  final String _device;
  List<InboxItem> _items = const [];
  int _unread = 0;
  Timer? _timer;
  bool _disposed = false;

  InboxService({this._api, LocalStore? store}) : _device = store?.deviceId ?? '' {
    if (_api == null) return;
    refresh();
    _timer = Timer.periodic(refreshEvery, (_) => refresh());
    WidgetsBinding.instance.addObserver(this);
  }

  bool get available => _api != null;
  List<InboxItem> get items => _items;
  int get unread => _unread;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refresh();
  }

  Future<void> refresh() async {
    try {
      final res = await _api!.get(
          '/api/notifications?device=${Uri.encodeQueryComponent(_device)}');
      _items = [
        for (final j in res['items'] as List? ?? const [])
          InboxItem.fromJson(j as Map<String, dynamic>),
      ];
      _unread = (res['unread'] as num?)?.toInt() ?? 0;
      _notify();
    } on ApiException catch (e) {
      debugPrint('알림함 받기 실패: $e');
    }
  }

  /// 하나를 읽음으로 (화면은 바로 바꾸고 서버에 알린다)
  Future<void> markRead(InboxItem item) async {
    if (item.read) return;
    _items = [for (final i in _items) i.id == item.id ? i.markedRead() : i];
    _unread = (_unread - 1).clamp(0, 1 << 30);
    _notify();
    await _post({'ids': [item.id]});
  }

  Future<void> markAllRead() async {
    _items = [for (final i in _items) i.markedRead()];
    _unread = 0;
    _notify();
    await _post({'all': true, 'device': _device});
  }

  Future<void> _post(Map<String, Object> body) async {
    try {
      await _api?.post('/api/notifications/read', body);
    } on ApiException catch (e) {
      debugPrint('알림 읽음 처리 실패: $e');
    }
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    if (_api != null) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
