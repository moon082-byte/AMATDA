import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// 숫자 키패드 + 입력 칸 점. [length]자리를 다 누르면 [onCompleted]를 부르고 비운다.
class PinPad extends StatefulWidget {
  final String title;
  final String? subtitle;
  final int length;

  /// 빨간 안내 문구 (틀림, 잠금 등)
  final String? error;

  /// false면 누를 수 없다 (잠금 중, 확인 중)
  final bool enabled;
  final ValueChanged<String> onCompleted;

  const PinPad({
    super.key,
    required this.title,
    this.subtitle,
    this.length = 4,
    this.error,
    this.enabled = true,
    required this.onCompleted,
  });

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _value = '';

  @override
  void didUpdateWidget(PinPad old) {
    super.didUpdateWidget(old);
    // 다른 단계로 넘어가면 입력을 비운다
    if (old.title != widget.title) _value = '';
  }

  void _press(String key) {
    if (!widget.enabled) return;
    setState(() {
      _value = key == '<'
          ? _value.substring(0, (_value.length - 1).clamp(0, _value.length))
          : (_value + key).substring(0, (_value.length + 1).clamp(0, widget.length));
    });
    if (_value.length == widget.length) {
      final value = _value;
      setState(() => _value = '');
      widget.onCompleted(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.title, style: text.h2, textAlign: TextAlign.center),
        if (widget.subtitle != null) ...[
          const SizedBox(height: 8),
          Text(widget.subtitle!,
              textAlign: TextAlign.center,
              style: text.body.copyWith(color: palette.subText)),
        ],
        const SizedBox(height: 28),
        Semantics(
          label: '${_value.length}자리 입력됨',
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < widget.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 9),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _value.length ? palette.accent : palette.border,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 48,
          child: Center(
            child: Text(widget.error ?? '',
                textAlign: TextAlign.center,
                style: text.caption.copyWith(color: palette.danger)),
          ),
        ),
        for (final row in const [['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['', '0', '<']])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final key in row) _key(key, text, palette)],
          ),
      ],
    );
  }

  Widget _key(String key, AppTypography text, AppPalette palette) {
    if (key.isEmpty) return const SizedBox(width: 88, height: 64);
    return SizedBox(
      width: 88,
      height: 64,
      child: TextButton(
        onPressed: widget.enabled ? () => _press(key) : null,
        style: TextButton.styleFrom(
          shape: const CircleBorder(),
          foregroundColor: palette.titleText,
        ),
        child: key == '<'
            ? Icon(Icons.backspace_outlined, semanticLabel: '지우기', color: palette.subText)
            : Text(key, style: text.h1.copyWith(fontWeight: FontWeight.w500)),
      ),
    );
  }
}
