import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/memo.dart';
import '../providers/memo_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/confirm_action.dart';
import '../utils/confirm_dialog.dart';
import '../utils/ids.dart';
import '../utils/memo_actions.dart';
import '../widgets/common/app_page.dart';
import '../widgets/field_label.dart';

/// 메모 쓰기·고치기 화면: 제목, 내용, [저장]. 고칠 때는 [삭제]도 있다.
/// 저장하지 않은 내용이 있으면 닫기 전에 확인한다.
class MemoEditPage extends StatefulWidget {
  final Memo? memo;
  const MemoEditPage({super.key, this.memo});

  @override
  State<MemoEditPage> createState() => _MemoEditPageState();
}

class _MemoEditPageState extends State<MemoEditPage> {
  late final _title = TextEditingController(text: widget.memo?.title ?? '');
  late final _content = TextEditingController(text: widget.memo?.content ?? '');
  bool _leaving = false;

  bool get _changed =>
      _title.text != (widget.memo?.title ?? '') ||
      _content.text != (widget.memo?.content ?? '');

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  void _close() {
    _leaving = true;
    Navigator.pop(context);
  }

  void _save() {
    final title = _title.text.trim();
    final content = _content.text.trimRight();
    if (title.isEmpty && content.trim().isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('제목이나 내용을 적어 주세요')));
      return;
    }
    final provider = context.read<MemoProvider>();
    final memo = widget.memo;
    if (memo == null) {
      final now = DateTime.now();
      provider.addMemo(Memo(
          id: newId('memo'), title: title, content: content, createdAt: now, updatedAt: now));
    } else if (title != memo.title || content != memo.content) {
      provider.updateMemo(memo.edited(title: title, content: content));
    }
    _close();
  }

  Future<void> _delete() async {
    final memo = widget.memo!;
    if (!await confirmDelete(context, '노션 연동 중이면 노션 페이지도 휴지통으로 옮겨요.')) return;
    if (!mounted) return;
    deleteMemoWithUndo(context, memo);
    _close();
  }

  Future<void> _confirmDiscard() async {
    final ok = await confirmAction(context,
        title: '저장하지 않고 나갈까요?', message: '고친 내용은 사라져요.', confirmLabel: '나가기');
    if (ok && mounted) _close();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    return ListenableBuilder(
      listenable: Listenable.merge([_title, _content]),
      builder: (context, _) => PopScope(
        canPop: _leaving || !_changed,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _confirmDiscard();
        },
        child: AppPage(
          title: widget.memo == null ? '새 메모' : '메모 수정',
          closeIcon: true,
          actions: [
            if (widget.memo != null)
              IconButton(
                onPressed: _delete,
                tooltip: '삭제',
                icon: Icon(Icons.delete_outline_rounded, color: palette.danger),
              ),
            TextButton(onPressed: _save, child: const Text('저장')),
          ],
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              sliver: SliverList.list(children: [
                const FieldLabel('제목'),
                TextField(
                  controller: _title,
                  autofocus: widget.memo == null,
                  textInputAction: TextInputAction.next,
                  style: text.title,
                  decoration: const InputDecoration(hintText: '제목 (비우면 내용 첫 줄)'),
                ),
                const SizedBox(height: 20),
                const FieldLabel('내용'),
                TextField(
                  controller: _content,
                  minLines: 8,
                  maxLines: null,
                  keyboardType: TextInputType.multiline,
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  style: text.body.copyWith(color: palette.titleText),
                  decoration: const InputDecoration(hintText: '떠오른 생각을 적어 보세요'),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }
}
