import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/note.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'slidable_actions.dart';

/// 메모 한 개. 밀어서 [수정]을 누르면 그 자리에서 고칠 수 있다.
class NoteTile extends StatefulWidget {
  final Note note;
  final ValueChanged<String> onSave;
  final VoidCallback onDelete;

  const NoteTile({
    super.key,
    required this.note,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<NoteTile> createState() => _NoteTileState();
}

class _NoteTileState extends State<NoteTile> {
  final _controller = TextEditingController();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _startEdit() {
    _controller.text = widget.note.content;
    setState(() => _editing = true);
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) return;
    if (value != widget.note.content) widget.onSave(value);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final note = widget.note;

    final body = Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: palette.warningSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: _editing
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                TextField(
                  controller: _controller,
                  autofocus: true,
                  minLines: 1,
                  maxLines: 6,
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  style: text.body.copyWith(
                    fontSize: 14,
                    color: palette.titleText,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    fillColor: palette.card,
                    contentPadding: const EdgeInsets.all(10),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () => setState(() => _editing = false),
                      child: const Text('취소'),
                    ),
                    TextButton(
                      onPressed: _controller.text.trim().isEmpty ? null : _save,
                      child: const Text('저장'),
                    ),
                  ],
                ),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.content,
                  style: text.body.copyWith(
                    fontSize: 14,
                    color: palette.titleText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  formatRelativeDateTime(note.createdAt),
                  style: text.micro.copyWith(fontWeight: FontWeight.w500),
                ),
              ],
            ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Slidable(
        key: ValueKey(note.id),
        enabled: !_editing,
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.5,
          children: buildEditDeleteActions(
            context,
            onEdit: _startEdit,
            onDelete: widget.onDelete,
          ),
        ),
        child: body,
      ),
    );
  }
}
