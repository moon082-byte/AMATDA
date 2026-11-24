import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/memo.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'common/app_card.dart';
import 'slidable_actions.dart';

/// 메모 목록의 한 줄: 제목, 내용 미리보기, 수정 시각, 노션 반영 상태.
/// 누르면 편집, 밀면 [수정][삭제].
class MemoTile extends StatelessWidget {
  final Memo memo;
  final MemoNotionState notion;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const MemoTile({
    super.key,
    required this.memo,
    required this.notion,
    required this.onTap,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final preview = memo.title.trim().isEmpty
        ? memo.content.trim().split('\n').skip(1).join(' ').trim()
        : memo.content.trim().replaceAll('\n', ' ');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.44,
          children: buildEditDeleteActions(context, onEdit: onTap, onDelete: onDelete),
        ),
        child: AppCard(
          onTap: onTap,
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(memo.displayTitle,
                  style: text.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (preview.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(preview,
                    style: text.caption, maxLines: 2, overflow: TextOverflow.ellipsis),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(formatRelativeDateTime(memo.updatedAt), style: text.micro),
                  const Spacer(),
                  _NotionBadge(notion),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 노션 반영 상태 표시 (연동을 켜지 않았으면 아무것도 없음)
class _NotionBadge extends StatelessWidget {
  final MemoNotionState state;
  const _NotionBadge(this.state);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final (IconData icon, String label, Color color) = switch (state) {
      MemoNotionState.none => (Icons.circle, '', p.subText),
      MemoNotionState.pending => (Icons.schedule_rounded, '노션 반영 중', p.subText),
      MemoNotionState.saved => (Icons.check_circle_rounded, '노션 저장됨', p.success),
      MemoNotionState.failed => (Icons.error_rounded, '노션 저장 실패', p.danger),
    };
    if (state == MemoNotionState.none) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: context.text.micro.copyWith(color: color)),
      ],
    );
  }
}
