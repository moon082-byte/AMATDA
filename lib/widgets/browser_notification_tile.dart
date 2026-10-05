import 'package:flutter/material.dart';
import '../services/browser_notifications.dart';
import '../theme/app_palette.dart';
import 'settings_group.dart';

/// 설정 화면의 '휴대폰 알림(브라우저)' 상태 줄. 아직 묻지 않았으면 허용 버튼을 보여준다.
class BrowserNotificationTile extends StatefulWidget {
  const BrowserNotificationTile({super.key});

  @override
  State<BrowserNotificationTile> createState() =>
      _BrowserNotificationTileState();
}

class _BrowserNotificationTileState extends State<BrowserNotificationTile> {
  String _permission = notificationPermission();

  Future<void> _request() async {
    final result = await requestNotificationPermission();
    if (mounted) setState(() => _permission = result);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final (subtitle, trailing) = switch (_permission) {
      'granted' => ('앱이 백그라운드에 있어도 알려드려요', null),
      'denied' => ('차단됨 · 브라우저 사이트 설정에서 허용해 주세요', null),
      'default' => (
          '허용하면 다른 앱을 보고 있을 때도 알려드려요',
          FilledButton(
            onPressed: _request,
            style: FilledButton.styleFrom(
              minimumSize: const Size(64, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('허용', style: TextStyle(fontSize: 14)),
          ),
        ),
      _ => ('이 브라우저는 알림을 지원하지 않아 앱 안에서만 알려드려요', null),
    };

    return SettingsTile(
      icon: _permission == 'granted'
          ? Icons.mark_chat_read_rounded
          : Icons.phonelink_ring_rounded,
      iconColor: _permission == 'granted' ? palette.success : palette.subText,
      title: '휴대폰 알림',
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}
