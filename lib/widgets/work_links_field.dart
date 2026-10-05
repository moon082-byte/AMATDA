import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/links.dart';
import 'field_label.dart';

/// 업무 링크 여러 개 입력란. 각 줄 오른쪽 X로 지우고, 아래 버튼으로 줄을 추가한다.
/// 입력 상태(컨트롤러 목록)는 부모 화면이 갖는다.
class WorkLinksField extends StatelessWidget {
  final List<TextEditingController> controllers;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;

  const WorkLinksField({
    super.key,
    required this.controllers,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const FieldLabel('업무 링크 (텔레그램, 카카오톡, 블로그, 노션 등)'),
        for (var i = 0; i < controllers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: ValueListenableBuilder(
              valueListenable: controllers[i],
              builder: (context, value, _) {
                final url = normalizeUrl(value.text);
                return TextField(
                  controller: controllers[i],
                  keyboardType: TextInputType.url,
                  style: text.body.copyWith(color: palette.titleText),
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  decoration: InputDecoration(
                    hintText: 'https://notion.so/...',
                    prefixIcon: Icon(
                      url.isEmpty ? Icons.link_rounded : linkService(url).$2,
                      size: 20,
                      color: url.isEmpty ? palette.subText : palette.accent,
                    ),
                    suffixIcon: IconButton(
                      onPressed: () => onRemove(i),
                      tooltip: '이 링크 지우기',
                      icon: Icon(Icons.cancel_rounded,
                          size: 20, color: palette.checkboxIdle),
                    ),
                  ),
                );
              },
            ),
          ),
        TextButton.icon(
          onPressed: onAdd,
          style: TextButton.styleFrom(
            backgroundColor: palette.accentSoft,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppPalette.fieldRadius),
            ),
          ),
          icon: const Icon(Icons.add_rounded, size: 20),
          label: const Text('링크 추가'),
        ),
      ],
    );
  }
}
