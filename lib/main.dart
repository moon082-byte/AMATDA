import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'data/local_store.dart';
import 'providers/notification_provider.dart';
import 'providers/room_provider.dart';
import 'providers/theme_provider.dart';
import 'services/telegram_link.dart';
import 'theme/app_theme.dart';
import 'views/main_dashboard_view.dart';
import 'widgets/phone_frame.dart';
import 'widgets/reminder_host.dart';
import 'widgets/telegram_sync_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Pretendard (AmatdaSans)'], ofl);
  });
  runApp(MyApp(store: await LocalStore.open()));
}

class MyApp extends StatelessWidget {
  /// 데이터 저장소. 없으면(테스트 등) 저장하지 않고 샘플 데이터로 동작한다.
  final LocalStore? store;

  const MyApp({super.key, this.store});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RoomProvider(store: store)),
        ChangeNotifierProvider(create: (_) => ThemeProvider(store: store)),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(store: store),
        ),
        ChangeNotifierProvider(create: (_) => TelegramLink(store: store)),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: '아맞다',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            builder: (context, child) => PhoneFrame(
              child: ReminderHost(
                store: store,
                child: TelegramSyncHost(child: child!),
              ),
            ),
            home: const MainDashboardView(),
          );
        },
      ),
    );
  }
}
