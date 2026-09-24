import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/notification_provider.dart';
import 'providers/room_provider.dart';
import 'providers/theme_provider.dart';
import 'theme/app_theme.dart';
import 'views/main_dashboard_view.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => RoomProvider()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => NotificationProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: '아맞다',
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeProvider.themeMode,
            home: const MainDashboardView(),
          );
        },
      ),
    );
  }
}
