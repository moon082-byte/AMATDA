import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../providers/routine_provider.dart';
import '../services/telegram_link.dart';
import '../services/telegram_payload.dart';

/// 할 일·업무방·루틴이 바뀌면 잠시 뒤(연속 변경은 한 번에) 알림 일정을 봇 서버에 올리고,
/// 앱으로 돌아올 때마다 텔레그램 연결 상태를 확인한다.
/// 루틴은 앞으로 7일 치만 올리므로, 앱을 켜 둔 동안에도 1시간마다 다시 계산해 올린다.
class TelegramSyncHost extends StatefulWidget {
  final Widget child;

  const TelegramSyncHost({super.key, required this.child});

  @override
  State<TelegramSyncHost> createState() => _TelegramSyncHostState();
}

class _TelegramSyncHostState extends State<TelegramSyncHost>
    with WidgetsBindingObserver {
  late final RoomProvider _rooms = context.read<RoomProvider>();
  late final RoutineProvider _routines = context.read<RoutineProvider>();
  late final TelegramLink _link = context.read<TelegramLink>();
  Timer? _debounce;
  Timer? _hourly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _rooms.addListener(_schedule);
    _routines.addListener(_schedule);
    _link.addListener(_schedule);
    _hourly = Timer.periodic(const Duration(hours: 1), (_) => _schedule());
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshThenSync());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rooms.removeListener(_schedule);
    _routines.removeListener(_schedule);
    _link.removeListener(_schedule);
    _debounce?.cancel();
    _hourly?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 텔레그램에서 '시작'을 누르고 돌아오면 바로 연결을 확인한다
    if (state == AppLifecycleState.resumed) _refreshThenSync();
  }

  Future<void> _refreshThenSync() async {
    if (!_link.available) return;
    await _link.refresh();
    _schedule();
  }

  void _schedule() {
    if (!_link.linked) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(seconds: 2), () {
      _link.sync(buildTelegramReminders(
        tasks: _rooms.tasks,
        rooms: _rooms.rooms,
        routines: _routines.routines,
        now: DateTime.now(),
      ));
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
