import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// 한 줄 입력 + 추가 버튼 (세부 항목/메모 추가 공용)
class InlineAddField extends StatefulWidget {
  final String hint;
  final ValueChanged<String> onAdd;

  const InlineAddField({super.key, required this.hint, required this.onAdd});

  @override
  State<InlineAddField> createState() => _InlineAddFieldState();
}

class _InlineAddFieldState extends State<InlineAddField> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    widget.onAdd(value);
    _controller.clear();
    _keepAboveKeyboard();
  }

  /// 항목이 추가되면 목록이 늘어 입력칸이 아래로(키보드 밑으로) 밀린다.
  /// 그대로 두면 아이폰은 페이지 전체를 위로 밀어 올리므로, 입력칸을 키보드 바로 위로 다시 맞춘다.
  void _keepAboveKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = mounted ? context.findRenderObject() as RenderBox? : null;
      if (box == null || !box.attached) return;
      box.showOnScreen(
        rect: Offset.zero & Size(box.size.width, box.size.height + 80),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final canAdd = _controller.text.trim().isNotEmpty;

    return TextField(
      controller: _controller,
      // 키보드가 올라와도 입력칸 아래로 여유 공간을 두고 보이게 한다
      scrollPadding: const EdgeInsets.only(bottom: 160),
      style: context.text.body.copyWith(
        fontSize: 14,
        color: palette.titleText,
      ),
      onSubmitted: (_) => _submit(),
      decoration: InputDecoration(
        hintText: widget.hint,
        contentPadding: const EdgeInsets.fromLTRB(14, 12, 4, 12),
        suffixIcon: IconButton(
          onPressed: canAdd ? _submit : null,
          tooltip: '추가',
          icon: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: canAdd ? palette.accent : palette.checkboxIdle,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.arrow_upward_rounded,
              size: 16,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
