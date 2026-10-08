import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/local_store.dart';
import '../providers/room_provider.dart';
import '../providers/routine_provider.dart';
import '../services/api_client.dart';
import '../services/sync_service.dart';
import '../services/telegram_link.dart';
import '../services/telegram_nag.dart';
import 'reminder_host.dart';
import 'telegram_sync_host.dart';

/// 한 계정의 데이터(업무방·할 일·루틴), 동기화, 텔레그램 연결과 알림을 묶어 제공한다.
/// [api]가 없으면(테스트) 서버 없이 이 기기에서만 동작한다.
class SessionScope extends StatelessWidget {
  final LocalStore? store;
  final ApiClient? api;
  final Widget child;

  const SessionScope({super.key, this.store, this.api, required this.child});

  @override
  Widget build(BuildContext context) {
    final store = this.store;
    final api = this.api;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RoomProvider(store: store)),
        ChangeNotifierProvider(create: (_) => RoutineProvider(store: store)),
        ChangeNotifierProvider(
          create: (_) => TelegramLink(api: api, store: store),
        ),
        ChangeNotifierProvider(create: (_) => TelegramNag(api: api)),
        if (api != null && store != null)
          ChangeNotifierProvider(
            lazy: false,
            create: (context) => SyncService(
              api: api,
              store: store,
              rooms: context.read<RoomProvider>(),
              routines: context.read<RoutineProvider>(),
            )..start(),
          ),
      ],
      child: ReminderHost(
        store: store,
        child: TelegramSyncHost(child: child),
      ),
    );
  }
}
