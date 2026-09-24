import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// 업무방 상세 화면 최상단 바: 뒤로가기 + 방 이름 + 방 삭제 버튼
class RoomDetailTitleBar extends StatelessWidget {
  final String name;
  final VoidCallback onDelete;

  const RoomDetailTitleBar({
    super.key,
    required this.name,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: palette.titleText,
          ),
        ),
        Expanded(
          child: Text(
            name,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: palette.titleText,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        IconButton(
          onPressed: onDelete,
          icon: const Icon(
            Icons.delete_outline,
            size: 20,
            color: Color(0xFFFF5B5B),
          ),
        ),
      ],
    );
  }
}
