import 'package:flutter/material.dart';
import '../theme/app_palette.dart';

/// 바텀시트 상단의 드래그 핸들 바
class SheetDragHandle extends StatelessWidget {
  const SheetDragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: palette.checkboxIdle,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
