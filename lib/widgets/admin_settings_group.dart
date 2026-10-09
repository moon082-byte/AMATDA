import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_palette.dart';
import '../utils/maybe_provider.dart';
import '../views/allowed_emails_page.dart';
import 'settings_group.dart';

/// 설정 화면 '관리자' 그룹: 관리자(OWNER_EMAIL) 계정에만 보인다
class AdminSettingsGroup extends StatelessWidget {
  const AdminSettingsGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = maybeProvider<AuthService>(context);
    if (auth == null || auth.user?.owner != true) return const SizedBox.shrink();
    final palette = context.palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: SettingsGroup(
        title: '관리자',
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AllowedEmailsPage(api: auth.api)),
            ),
            child: SettingsTile(
              icon: Icons.admin_panel_settings_rounded,
              iconColor: palette.accent,
              title: '허용 이메일 관리',
              subtitle: '로그인할 수 있는 구글 계정을 추가·삭제해요',
              trailing: Icon(Icons.chevron_right_rounded, color: palette.checkboxIdle),
            ),
          ),
        ],
      ),
    );
  }
}
