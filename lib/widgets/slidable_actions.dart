import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

/// 항목을 옆으로 슬라이드했을 때 나타나는 '수정'/'삭제' 액션 목록
List<Widget> buildEditDeleteActions({
  required VoidCallback onEdit,
  required VoidCallback onDelete,
}) {
  return [
    SlidableAction(
      onPressed: (_) => onEdit(),
      backgroundColor: const Color(0xFF3182F6),
      foregroundColor: Colors.white,
      icon: Icons.edit_outlined,
      label: '수정',
      borderRadius: BorderRadius.circular(20),
    ),
    SlidableAction(
      onPressed: (_) => onDelete(),
      backgroundColor: const Color(0xFFFF5B5B),
      foregroundColor: Colors.white,
      icon: Icons.delete_outline,
      label: '삭제',
      borderRadius: BorderRadius.circular(20),
    ),
  ];
}
