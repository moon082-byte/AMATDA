import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/inbox_item.dart';
import '../services/inbox_service.dart';
import '../services/launch_link.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import '../widgets/common/app_card.dart';
import '../widgets/common/app_page.dart';
import '../widgets/common/empty_state.dart';
import 'launch_target.dart';

/// 앱 알림함: 다른 기기에서 바꾼 할 일, 보낸 리마인더 (최신순). 누르면 읽음 처리하고 그 화면으로 간다.
class InboxView extends StatefulWidget {
  const InboxView({super.key});

  @override
  State<InboxView> createState() => _InboxViewState();
}

class _InboxViewState extends State<InboxView> {
  @override
  void initState() {
    super.initState();
    context.read<InboxService>().refresh();
  }

  Future<void> _open(InboxItem item) async {
    final inbox = context.read<InboxService>();
    inbox.markRead(item);
    final target = parseTargetValue(item.target);
    if (target != null) await openTarget(context, target);
  }

  @override
  Widget build(BuildContext context) {
    final inbox = context.watch<InboxService>();
    return AppPage(
      title: '알림함',
      subtitle: inbox.unread == 0 ? null : '안 읽은 알림 ${inbox.unread}개',
      actions: [
        if (inbox.unread > 0)
          TextButton(onPressed: inbox.markAllRead, child: const Text('모두 읽음')),
      ],
      slivers: [
        paddedSliver(top: 12, [
          if (inbox.items.isEmpty)
            const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: '아직 알림이 없어요',
              message: '다른 기기에서 할 일을 바꾸거나 리마인더가 울리면 여기에 모여요',
            ),
          for (final item in inbox.items)
            _InboxTile(item: item, onTap: () => _open(item)),
        ]),
      ],
    );
  }
}

class _InboxTile extends StatelessWidget {
  final InboxItem item;
  final VoidCallback onTap;

  const _InboxTile({required this.item, required this.onTap});

  static IconData _icon(String kind) => switch (kind) {
        'reminder' => Icons.notifications_active_rounded,
        'task_added' => Icons.add_task_rounded,
        'task_done' => Icons.task_alt_rounded,
        'task_deleted' => Icons.delete_outline_rounded,
        _ => Icons.edit_note_rounded,
      };

  /// "방금", "5분 전", "3시간 전", 그 외 "어제 18:00"
  static String _when(DateTime at) {
    final diff = DateTime.now().difference(at);
    if (diff.inMinutes < 1) return '방금';
    if (diff.inHours < 1) return '${diff.inMinutes}분 전';
    if (diff.inHours < 12) return '${diff.inHours}시간 전';
    return '${formatDayGroup(at)} ${formatTime(at)}';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final unread = !item.read;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(_icon(item.kind),
                size: 22, color: unread ? palette.accent : palette.subText),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    style: text.title.copyWith(
                      fontWeight: unread ? FontWeight.w700 : FontWeight.w500,
                      color: unread ? palette.titleText : palette.subText,
                    ),
                  ),
                  if (item.body.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(item.body, style: text.body.copyWith(color: palette.bodyText)),
                  ],
                  const SizedBox(height: 6),
                  Text(_when(item.createdAt), style: text.caption),
                ],
              ),
            ),
            if (unread)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.only(top: 6, left: 8),
                decoration: BoxDecoration(color: palette.accent, shape: BoxShape.circle),
              ),
          ],
        ),
      ),
    );
  }
}
