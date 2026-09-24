import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../theme/app_palette.dart';

/// 항목을 옆으로 슬라이드했을 때 나타나는 '수정'/'삭제' 액션 목록
List<Widget> buildEditDeleteActions(
  BuildContext context, {
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  final p = context.palette;
  return [
    _action(color: p.accent, icon: Icons.edit_rounded, label: '수정', onTap: onEdit),
    _action(color: p.danger, icon: Icons.delete_rounded, label: '삭제', onTap: onDelete),
  ];
}

/// 아카이브 항목용 '복원'/'삭제' 액션 목록
List<Widget> buildRestoreDeleteActions(
  BuildContext context, {
  required VoidCallback onRestore,
  required VoidCallback onDelete,
}) {
  final p = context.palette;
  return [
    _action(color: p.accent, icon: Icons.undo_rounded, label: '복원', onTap: onRestore),
    _action(color: p.danger, icon: Icons.delete_rounded, label: '삭제', onTap: onDelete),
  ];
}

/// 카드와 간격을 두고 떠 있는 둥근 액션 버튼
Widget _action({
  required Color color,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
}) {
  return CustomSlidableAction(
    onPressed: (_) => onTap(),
    backgroundColor: Colors.transparent,
    foregroundColor: Colors.white,
    padding: EdgeInsets.zero,
    child: Container(
      margin: const EdgeInsets.only(left: 8),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(AppPalette.cardRadius),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: Colors.white),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ),
  );
}
