import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'sheet_drag_handle.dart';

/// 할 일·루틴 입력 블록의 공통 틀 (아래에서 올라오는 시트, 키보드 바로 위에 붙는다).
/// 한 줄 구성: [이름 입력칸][📅 [schedule]][🔔 [bell]]
/// [linkField]가 있으면 두 줄: [이름][📅] / [링크 입력칸][🔔]
class ComposerFrame extends StatelessWidget {
  final String title;
  final TextEditingController controller;
  final String hint;
  final bool autofocus;

  /// 이름을 바꿀 수 없게 (프로젝트에서 배정된 업무)
  final bool readOnly;
  final Widget schedule;
  final Widget bell;

  /// 둘째 줄 왼쪽 입력칸 (할 일의 텔레그램 메시지 링크)
  final Widget? linkField;

  /// 입력 줄 아래에 덧붙일 칸 (예: 업무방 선택)
  final List<Widget> extra;
  final String submitLabel;
  final VoidCallback? onSubmit;

  const ComposerFrame({
    super.key,
    required this.title,
    required this.controller,
    required this.hint,
    required this.schedule,
    required this.bell,
    required this.submitLabel,
    required this.onSubmit,
    this.autofocus = false,
    this.readOnly = false,
    this.linkField,
    this.extra = const [],
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final media = MediaQuery.of(context);

    return Container(
      decoration: BoxDecoration(
        color: palette.card,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: EdgeInsets.only(
        bottom: media.viewInsets.bottom + media.padding.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetDragHandle(),
            const SizedBox(height: 16),
            Text(title, style: text.h2),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    autofocus: autofocus,
                    readOnly: readOnly,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onSubmit?.call(),
                    style: text.body.copyWith(color: palette.titleText),
                    decoration: InputDecoration(hintText: hint),
                  ),
                ),
                const SizedBox(width: 6),
                schedule,
                if (linkField == null) ...[const SizedBox(width: 6), bell],
              ],
            ),
            if (linkField case final link?) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: link),
                  const SizedBox(width: 6),
                  bell,
                ],
              ),
            ],
            for (final w in extra) ...[const SizedBox(height: 20), w],
            const SizedBox(height: 20),
            FilledButton(onPressed: onSubmit, child: Text(submitLabel)),
          ],
        ),
      ),
    );
  }
}
