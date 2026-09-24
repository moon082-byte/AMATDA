import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_palette.dart';
import '../widgets/settings_group.dart';
import '../widgets/theme_mode_selector.dart';

/// 설정 화면: 알림 On/Off, 테마 모드 전환
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Scaffold(
      backgroundColor: palette.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 20, 40),
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.arrow_back_ios_new,
                    size: 18,
                    color: palette.titleText,
                  ),
                ),
                Text(
                  '설정',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: palette.titleText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SettingsGroup(
                title: '알림',
                children: [
                  Consumer<NotificationProvider>(
                    builder: (context, notif, _) => SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '전체 알림',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: palette.titleText,
                        ),
                      ),
                      subtitle: Text(
                        '업무 리마인더 알림을 받아요',
                        style: TextStyle(fontSize: 12, color: palette.subText),
                      ),
                      value: notif.enabled,
                      activeThumbColor: palette.accent,
                      onChanged: (_) => notif.toggle(),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: SettingsGroup(
                title: '테마',
                children: [
                  Consumer<ThemeProvider>(
                    builder: (context, themeProvider, _) => ThemeModeSelector(
                      value: themeProvider.themeMode,
                      onChanged: themeProvider.setThemeMode,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
