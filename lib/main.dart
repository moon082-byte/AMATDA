import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'data/local_store.dart';
import 'providers/notification_provider.dart';
import 'providers/theme_provider.dart';
import 'services/auth_service.dart';
import 'services/launch_link.dart';
import 'theme/app_theme.dart';
import 'views/main_dashboard_view.dart';
import 'widgets/auth_gate.dart';
import 'widgets/phone_frame.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final login = captureStartupParams();
  LicenseRegistry.addLicense(() async* {
    final ofl = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Pretendard (AmatdaSans)'], ofl);
  });
  final store = await LocalStore.open();
  final auth = AuthService(store: store)
    ..init(loginCode: login.code, loginError: login.error);
  runApp(MyApp(store: store, auth: auth));
}

class MyApp extends StatelessWidget {
  /// 기기 저장소. 없으면(테스트 등) 로그인 없이 저장하지 않고 샘플 데이터로 동작한다.
  final LocalStore? store;

  /// 구글 로그인 상태. 없으면 로그인 화면 없이 바로 앱을 보여준다(테스트 등).
  final AuthService? auth;

  const MyApp({super.key, this.store, this.auth});

  @override
  Widget build(BuildContext context) {
    final auth = this.auth;
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider(store: store)),
        ChangeNotifierProvider(
          create: (_) => NotificationProvider(store: store),
        ),
        if (auth != null) ChangeNotifierProvider.value(value: auth),
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
              child: AuthGate(auth: auth, store: store, child: child!),
            ),
            home: const MainDashboardView(),
          );
        },
      ),
    );
  }
}
