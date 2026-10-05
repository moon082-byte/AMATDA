import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/links.dart';
import 'sheet_drag_handle.dart';

/// 업무방에 등록된 외부 링크 목록을 팝업으로 띄우고, 고른 링크를 연다
Future<void> showLinkPicker(BuildContext context, List<String> links) {
  return showModalBottomSheet(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) {
      final palette = sheetContext.palette;
      final text = sheetContext.text;

      return Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
            12, 12, 12, 16 + MediaQuery.of(sheetContext).padding.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetDragHandle(),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 20, 12, 8),
              child: Text('외부 링크 열기', style: text.h2),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final link in links)
                    _LinkRow(
                      link: link,
                      onTap: () {
                        Navigator.pop(sheetContext);
                        openExternalLink(context, link);
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}

class _LinkRow extends StatelessWidget {
  final String link;
  final VoidCallback onTap;

  const _LinkRow({required this.link, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final (service, icon) = linkService(link);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: palette.accentSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 20, color: palette.accent),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service, style: text.title),
                  Text(
                    link.replaceFirst(RegExp(r'^https?://(www\.)?'), ''),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: text.caption,
                  ),
                ],
              ),
            ),
            Icon(Icons.open_in_new_rounded, size: 20, color: palette.subText),
          ],
        ),
      ),
    );
  }
}
