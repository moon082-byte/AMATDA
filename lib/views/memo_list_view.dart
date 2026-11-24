import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/memo.dart';
import '../providers/memo_provider.dart';
import '../services/notion_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/maybe_provider.dart';
import '../utils/memo_actions.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/memo_tile.dart';
import 'memo_edit_page.dart';

/// [메모] 탭: 최근에 고친 메모부터. [새 메모]로 쓰고, 누르면 고치고, 밀어서 지운다.
/// 노션 연동을 켰으면 각 메모의 노션 반영 상태를 함께 보여준다.
class MemoListView extends StatelessWidget {
  const MemoListView({super.key});

  static Future<void> _open(BuildContext context, [Memo? memo]) => Navigator.push(
        context,
        MaterialPageRoute(fullscreenDialog: true, builder: (_) => MemoEditPage(memo: memo)),
      );

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final memos = context.watch<MemoProvider>().latestFirst;
    final notion = maybeProvider<NotionService>(context);
    final notionOn = notion?.enabled ?? false;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context),
        icon: const Icon(Icons.edit_note_rounded),
        label: const Text('새 메모'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
          children: [
            Text('메모', style: text.h1),
            const SizedBox(height: 4),
            Text(
              notionOn ? '메모 ${memos.length}개 · 노션 1_Inbox에 함께 저장돼요' : '메모 ${memos.length}개',
              style: text.body.copyWith(color: context.palette.subText),
            ),
            const SizedBox(height: 20),
            if (memos.isEmpty)
              const EmptyState(
                icon: Icons.sticky_note_2_rounded,
                title: '아직 메모가 없어요',
                message: '[새 메모]로 떠오른 생각을 적어 두세요',
              ),
            for (final memo in memos)
              MemoTile(
                key: ValueKey(memo.id),
                memo: memo,
                notion: memo.notionState(notionOn: notionOn),
                onTap: () => _open(context, memo),
                onDelete: () => deleteMemoWithUndo(context, memo),
              ),
          ],
        ),
      ),
    );
  }
}
