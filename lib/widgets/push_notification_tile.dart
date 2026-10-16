import 'package:flutter/material.dart';
import '../services/push_service.dart';
import '../theme/app_palette.dart';
import '../utils/maybe_provider.dart';
import 'browser_notification_tile.dart';
import 'settings_group.dart';

/// 설정 화면의 '시스템 알림' 줄: [알림 허용]을 누르면 이 기기(휴대폰·PC)를 푸시로 구독한다.
/// 로그인하지 않았거나 푸시를 못 쓰는 브라우저면 예전 브라우저 알림 줄을 보여준다.
class PushNotificationTile extends StatelessWidget {
  const PushNotificationTile({super.key});

  Future<void> _enable(BuildContext context, PushService push) async {
    final error = await push.enable();
    if (error == null || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final push = maybeProvider<PushService>(context);
    final state = push?.state ?? PushState.unavailable;
    if (push == null ||
        state == PushState.unavailable ||
        state == PushState.unsupported) {
      return const BrowserNotificationTile();
    }
    final palette = context.palette;
    final button = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(64, 36)),
      padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 14)),
      shape: WidgetStatePropertyAll(
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );

    final (subtitle, trailing) = switch (state) {
      PushState.on => (
          '앱을 닫아 둬도 이 기기로 리마인더를 알려드려요',
          TextButton(
            onPressed: push.busy ? null : push.disable,
            style: button,
            child: const Text('끄기', style: TextStyle(fontSize: 14)),
          ),
        ),
      PushState.needsHomeScreen => (
          '아이폰은 사파리 공유 버튼 → "홈 화면에 추가" 후, 홈 화면의 아맞다에서 켤 수 있어요',
          null,
        ),
      PushState.denied => (
          '차단됨 · 브라우저(아이폰은 설정 → 알림 → 아맞다)에서 허용해 주세요',
          null,
        ),
      _ => (
          '허용하면 앱을 닫아 둬도 리마인더 시각에 알려드려요',
          FilledButton(
            onPressed: push.busy ? null : () => _enable(context, push),
            style: button,
            child: push.busy
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('알림 허용', style: TextStyle(fontSize: 14)),
          ),
        ),
    };

    return SettingsTile(
      icon: state == PushState.on
          ? Icons.notifications_active_rounded
          : Icons.phonelink_ring_rounded,
      iconColor: state == PushState.on ? palette.success : palette.subText,
      title: '시스템 알림',
      subtitle: subtitle,
      trailing: trailing,
    );
  }
}
