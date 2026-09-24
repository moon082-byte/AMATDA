import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../widgets/common/page_header.dart';
import '../widgets/settings_group.dart';
import '../widgets/theme_mode_selector.dart';

/// 설정 화면: 알림 On/Off, 테마 모드 전환, 앱 정보
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final notif = context.watch<NotificationProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
          children: [
            const PageHeader(title: '설정'),
            const SizedBox(height: 28),
            SettingsGroup(
              title: '알림',
              children: [
                SettingsTile(
                  icon: Icons.notifications_rounded,
                  iconColor: palette.warning,
                  title: '전체 알림',
                  subtitle: '업무 리마인더 알림을 받아요',
                  trailing: Switch(
                    value: notif.enabled,
                    onChanged: (_) => notif.toggle(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            SettingsGroup(
              title: '화면',
              children: [
                Column(
                  children: [
                    SettingsTile(
                      icon: Icons.palette_rounded,
                      iconColor: palette.accent,
                      title: '테마',
                      subtitle: '앱의 밝기 모드를 선택해요',
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4, bottom: 14),
                      child: ThemeModeSelector(
                        value: themeProvider.themeMode,
                        onChanged: themeProvider.setThemeMode,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 28),
            SettingsGroup(
              title: '정보',
              children: [
                SettingsTile(
                  icon: Icons.info_rounded,
                  iconColor: palette.subText,
                  title: '버전',
                  trailing: Text('1.0.0', style: context.text.caption),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
