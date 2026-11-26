import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../utils/refresh_all.dart';

/// 헤더의 🔄 버튼: 누르면 서버 데이터를 다시 받고, 받는 동안 버튼 자리에 로딩 표시를 돌린다
class RefreshButton extends StatefulWidget {
  final ButtonStyle? style;
  const RefreshButton({super.key, this.style});

  @override
  State<RefreshButton> createState() => _RefreshButtonState();
}

class _RefreshButtonState extends State<RefreshButton> {
  bool _busy = false;

  Future<void> _refresh() async {
    setState(() => _busy = true);
    try {
      await refreshAll(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return IconButton(
      onPressed: _busy ? null : _refresh,
      tooltip: _busy ? '새로 받는 중' : '새로고침',
      style: widget.style,
      icon: _busy
          ? SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: palette.accent),
            )
          : Icon(Icons.refresh_rounded, color: palette.subText),
    );
  }
}
