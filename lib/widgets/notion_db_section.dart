import 'package:flutter/material.dart';
import '../models/notion_settings.dart';
import '../services/notion_db_draft.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';
import 'labeled_text_field.dart';
import 'notion_map_fields.dart';

/// 노션 설정의 데이터베이스 한 칸(할일용·메모용): 링크 붙여 넣기 → [속성 불러오기] → 매핑 고르기.
/// 이미 연결돼 있으면 [기존 항목 보내기]도 있다.
class NotionDbSection extends StatelessWidget {
  final NotionDbDraft draft;
  final VoidCallback onLoad;

  /// 연결돼 있고 연동이 켜져 있을 때만
  final VoidCallback? onBackfill;
  final bool busy;

  const NotionDbSection({
    super.key,
    required this.draft,
    required this.onLoad,
    this.onBackfill,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final label = draft.target.label;
    return ListenableBuilder(
      listenable: draft,
      builder: (context, _) => AppCard(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$label 데이터베이스', style: text.title),
            const SizedBox(height: 4),
            Text(
              draft.target == NotionTarget.task
                  ? '할 일을 만들고, 고치고, 완료하면 이 데이터베이스에도 반영해요'
                  : '메모를 저장하면 이 데이터베이스에도 페이지로 만들어요',
              style: text.caption,
            ),
            const SizedBox(height: 14),
            LabeledTextField(
              label: '연결할 노션 데이터베이스 링크 (비우면 연결 안 함)',
              controller: draft.link,
              hint: 'https://www.notion.so/…',
              keyboardType: TextInputType.url,
              onChanged: (_) => draft.linkChanged(),
            ),
            const SizedBox(height: 8),
            Row(children: [
              OutlinedButton.icon(
                onPressed: busy || draft.loading || draft.link.text.trim().isEmpty ? null : onLoad,
                icon: draft.loading
                    ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.download_rounded, size: 18),
                label: const Text('속성 불러오기'),
              ),
              const SizedBox(width: 8),
              if (draft.db case final db?)
                Expanded(
                  child: Text('"${db.name}" 연결됨',
                      style: text.caption.copyWith(color: palette.success),
                      overflow: TextOverflow.ellipsis),
                ),
            ]),
            if (draft.error case final error?) ...[
              const SizedBox(height: 8),
              Text(error, style: text.caption.copyWith(color: palette.danger)),
            ],
            if (draft.db != null) ...[
              const SizedBox(height: 16),
              NotionMapFields(draft: draft),
            ],
            if (onBackfill != null)
              TextButton.icon(
                onPressed: busy ? null : onBackfill,
                icon: const Icon(Icons.upload_rounded, size: 18),
                label: Text('기존 $label 노션에 보내기'),
              ),
          ],
        ),
      ),
    );
  }
}
