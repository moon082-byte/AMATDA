import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/telegram_link.dart';
import '../services/telegram_nag.dart';
import '../theme/app_palette.dart';
import 'settings_group.dart';

/// 설정 화면의 '끈질긴 알림' 켜기/끄기 줄 (텔레그램이 연결돼 있을 때만)
class TelegramNagTile extends StatelessWidget {
  const TelegramNagTile({super.key});

  Future<void> _toggle(BuildContext context, TelegramNag nag, bool on) async {
    final messenger = ScaffoldMessenger.of(context);
    final error = await nag.setEnabled(on);
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final link = context.watch<TelegramLink>();
    if (!link.available || !link.linked) return const SizedBox.shrink();
    final nag = context.watch<TelegramNag>();
    final palette = context.palette;

    return SettingsTile(
      icon: Icons.alarm_rounded,
      iconColor: nag.enabled ? palette.danger : palette.subText,
      title: '끈질긴 알림',
      subtitle: nag.enabled
          ? '[확인]을 누를 때까지 5분마다 최대 3번 더 알려요'
          : '텔레그램 알림을 한 번만 보내요',
      trailing: Switch(
        value: nag.enabled,
        onChanged: (on) => _toggle(context, nag, on),
      ),
    );
  }
}
