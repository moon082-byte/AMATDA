import 'package:flutter/material.dart';
import '../services/notion_service.dart';
import '../theme/app_palette.dart';
import '../utils/maybe_provider.dart';
import '../views/notion_settings_page.dart';
import 'settings_group.dart';

/// 설정 화면의 '연동' 묶음: 노션 연동 상태를 보여주고, 누르면 노션 연동 설정을 연다.
/// 로그인하지 않았으면(테스트·미리보기) 보이지 않는다.
class NotionSettingsGroup extends StatelessWidget {
  const NotionSettingsGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final notion = maybeProvider<NotionService>(context);
    if (notion == null || !notion.available) return const SizedBox.shrink();
    final palette = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: SettingsGroup(title: '연동', children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => const NotionSettingsPage())),
          child: SettingsTile(
            icon: Icons.menu_book_rounded,
            iconColor: notion.enabled ? palette.success : palette.subText,
            title: '노션',
            subtitle: notion.enabled ? '켜짐 · 메모를 노션 1_Inbox에 저장해요' : '꺼짐 · 메모를 노션 1_Inbox에 저장할 수 있어요',
            trailing: Icon(Icons.chevron_right_rounded, color: palette.checkboxIdle),
          ),
        ),
      ]),
    );
  }
}
