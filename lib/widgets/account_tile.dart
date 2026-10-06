import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../theme/app_palette.dart';
import '../utils/maybe_provider.dart';
import 'settings_group.dart';

/// 설정 화면 '계정' 그룹: 로그인한 구글 계정, 동기화 상태, 로그아웃
class AccountGroup extends StatelessWidget {
  const AccountGroup({super.key});

  Future<void> _logout(BuildContext context, AuthService auth) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('로그아웃할까요?'),
        content: const Text('데이터는 계정에 저장돼 있어서 다시 로그인하면 그대로 볼 수 있어요.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('취소'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
    if (ok == true) await auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final auth = maybeProvider<AuthService>(context);
    final user = auth?.user;
    if (auth == null || user == null) return const SizedBox.shrink();
    final palette = context.palette;
    final sync = maybeProvider<SyncService>(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: SettingsGroup(
        title: '계정',
        children: [
          SettingsTile(
            icon: Icons.account_circle_rounded,
            iconColor: palette.accent,
            title: user.name.isNotEmpty ? user.name : user.email,
            subtitle: '${user.email}\n${_syncLabel(sync)}',
            trailing: TextButton(
              onPressed: () => _logout(context, auth),
              style: TextButton.styleFrom(foregroundColor: palette.danger),
              child: const Text('로그아웃'),
            ),
          ),
        ],
      ),
    );
  }

  static String _syncLabel(SyncService? sync) {
    if (sync == null) return '';
    if (sync.error != null) return '오프라인 · 연결되면 자동으로 맞춰요';
    final at = sync.lastSyncedAt;
    if (at == null) return '동기화하는 중…';
    final minutes = DateTime.now().difference(at).inMinutes;
    return minutes < 1 ? '방금 동기화됨' : '$minutes분 전 동기화됨';
  }
}
