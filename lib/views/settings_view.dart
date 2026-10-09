import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import '../providers/room_provider.dart';
import '../providers/routine_provider.dart';
import '../providers/theme_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/confirm_dialog.dart';
import '../widgets/account_tile.dart';
import '../widgets/admin_settings_group.dart';
import '../widgets/common/app_page.dart';
import '../widgets/browser_notification_tile.dart';
import '../widgets/pin_settings_tile.dart';
import '../widgets/settings_group.dart';
import '../widgets/telegram_link_tile.dart';
import '../widgets/telegram_nag_tile.dart';
import '../widgets/theme_mode_selector.dart';

/// 설정 화면: 알림 On/Off, 테마 모드 전환, 데이터 초기화, 앱 정보
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  Future<void> _resetData(BuildContext context) async {
    final confirmed = await confirmDelete(
      context,
      '모든 업무방·할 일·루틴을 지워요. 같은 계정으로 로그인한 모든 기기에서 지워져요.',
    );
    if (!context.mounted || !confirmed) return;
    context.read<RoomProvider>().clearAll();
    context.read<RoutineProvider>().clearAll();
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('데이터를 초기화했어요')));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final notif = context.watch<NotificationProvider>();
    final themeProvider = context.watch<ThemeProvider>();

    return AppPage(
      title: '설정',
      slivers: [
        paddedSliver(top: 12, [
          const AccountGroup(),
          const PinSettingsGroup(),
          const AdminSettingsGroup(),
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
              if (notif.enabled) const BrowserNotificationTile(),
              if (notif.enabled) const TelegramLinkTile(),
              if (notif.enabled) const TelegramNagTile(),
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
            title: '데이터',
            children: [
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _resetData(context),
                child: SettingsTile(
                  icon: Icons.restart_alt_rounded,
                  iconColor: palette.danger,
                  title: '데이터 초기화',
                  subtitle: '모든 업무방·할 일·루틴을 지워요',
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: palette.checkboxIdle,
                  ),
                ),
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
        ]),
      ],
    );
  }
}
