import 'package:flutter/material.dart';
import '../services/pin_service.dart';
import '../theme/app_palette.dart';
import '../utils/maybe_provider.dart';
import '../views/pin_setup_page.dart';
import 'settings_group.dart';

/// 설정 화면 '보안' 그룹: PIN 사용 켜기/끄기, PIN 바꾸기
class PinSettingsGroup extends StatelessWidget {
  const PinSettingsGroup({super.key});

  Future<void> _run(BuildContext context, PinService pin, PinSetupMode mode) async {
    final messenger = ScaffoldMessenger.of(context);
    final done = await PinSetupPage.open(context, pin, mode);
    if (done != true) return;
    messenger.showSnackBar(SnackBar(
      content: Text(switch (mode) {
        PinSetupMode.enable => 'PIN을 켰어요. 앱을 열 때마다 PIN을 물어봐요',
        PinSetupMode.change => 'PIN을 바꿨어요. 다른 기기에서도 새 PIN을 입력해요',
        PinSetupMode.disable => 'PIN을 껐어요',
      }),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final pin = maybeProvider<PinService>(context);
    if (pin == null) return const SizedBox.shrink();
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: SettingsGroup(
        title: '보안',
        children: [
          SettingsTile(
            icon: Icons.lock_rounded,
            iconColor: pin.enabled ? palette.accent : palette.subText,
            title: '앱 잠금 (PIN)',
            subtitle: pin.enabled
                ? '앱을 열 때마다 4자리 PIN을 물어봐요'
                : '앱을 열 때 4자리 PIN으로 한 번 더 확인해요',
            trailing: Switch(
              value: pin.enabled,
              onChanged: (on) => _run(
                  context, pin, on ? PinSetupMode.enable : PinSetupMode.disable),
            ),
          ),
          if (pin.enabled)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _run(context, pin, PinSetupMode.change),
              child: SettingsTile(
                icon: Icons.password_rounded,
                iconColor: palette.subText,
                title: 'PIN 바꾸기',
                trailing: Icon(Icons.chevron_right_rounded,
                    color: palette.checkboxIdle),
              ),
            ),
        ],
      ),
    );
  }
}
