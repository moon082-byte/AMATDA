import 'package:flutter/material.dart';

/// 상태 버튼: 채운 버튼([완료]·[검토]) 또는 테두리 버튼([검토중])
class ProjectStatusButton extends StatelessWidget {
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const ProjectStatusButton(this.label, {super.key, required this.filled, this.onTap});

  @override
  Widget build(BuildContext context) {
    const style = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(56, 34)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12)),
    );
    final child = Text(label, style: const TextStyle(fontSize: 13));
    return filled
        ? FilledButton(onPressed: onTap, style: style, child: child)
        : OutlinedButton(onPressed: onTap, style: style, child: child);
  }
}
