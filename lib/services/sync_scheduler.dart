import 'dart:async';
import 'package:flutter/widgets.dart';

/// 언제 동기화할지 정한다.
/// - 앱 데이터가 바뀌면 2초 뒤 (연속 변경은 한 번에)
/// - 화면이 보이는 동안 30초마다 (숨겨져 있을 때는 쉰다)
/// - 앱·창으로 돌아오면 바로 (다른 기기에서 바꾼 내용이 바로 보이게)
/// - 앱을 떠날 때 아직 올리지 않은 변경이 있으면 바로 (휴대폰은 백그라운드에서 앱이 멈춘다)
class SyncScheduler {
  static const debounce = Duration(seconds: 2);
  static const interval = Duration(seconds: 30);

  final Future<void> Function() sync;
  final Listenable changes;

  /// true면 지금 바뀐 것은 동기화로 받은 내용이라 다시 올리지 않는다
  final bool Function() applying;

  Timer? _debounce;
  Timer? _ticker;
  AppLifecycleListener? _life;
  bool _visible = true;

  SyncScheduler({required this.sync, required this.changes, required this.applying});

  void start() {
    changes.addListener(_changed);
    _ticker = Timer.periodic(interval, (_) {
      if (_visible) sync();
    });
    _life = AppLifecycleListener(
      onShow: () => _visible = true,
      onResume: sync,
      onHide: _leave,
    );
  }

  void dispose() {
    changes.removeListener(_changed);
    _debounce?.cancel();
    _ticker?.cancel();
    _life?.dispose();
  }

  void _changed() {
    if (applying()) return;
    _debounce?.cancel();
    _debounce = Timer(debounce, sync);
  }

  void _leave() {
    _visible = false;
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
      sync();
    }
  }
}
