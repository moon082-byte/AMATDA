import 'package:flutter/material.dart';
import '../services/notion_service.dart';
import '../theme/app_palette.dart';
import 'settings_group.dart';

/// 노션 설정 맨 위 '연동' 묶음: [노션에 보내기] 스위치와 반영 현황
class NotionToggleGroup extends StatelessWidget {
  final NotionService service;
  final bool enabled;

  /// null이면 스위치를 잠시 잠근다 (저장 중)
  final ValueChanged<bool>? onChanged;

  const NotionToggleGroup({super.key, required this.service, required this.enabled, this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(title: '연동', children: [
      SettingsTile(
        icon: Icons.sync_rounded,
        iconColor: context.palette.accent,
        title: '노션에 보내기',
        subtitle: '고치면 노션도 고치고, 지우면 휴지통으로 옮겨요 (아맞다 → 노션)',
        trailing: Switch(value: enabled, onChanged: onChanged),
      ),
      if (service.enabled) NotionStatusTile(service: service),
    ]);
  }
}

/// 노션 반영 현황: 모두 보냈는지, 보내는 중인지, 실패해 다시 시도 중인지(이유와 함께)
class NotionStatusTile extends StatelessWidget {
  final NotionService service;
  const NotionStatusTile({super.key, required this.service});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (IconData icon, Color color, String title, String? subtitle) = service.failed > 0
        ? (Icons.error_rounded, p.danger, '노션에 보내지 못한 항목 ${service.failed}개', service.lastError)
        : service.waiting > 0
            ? (Icons.schedule_rounded, p.warning, '노션에 보내는 중 ${service.waiting}개', '1분 안에 반영돼요')
            : (Icons.check_circle_rounded, p.success, '모두 노션에 반영했어요', null);
    return SettingsTile(icon: icon, iconColor: color, title: title, subtitle: subtitle);
  }
}
