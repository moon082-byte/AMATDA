import 'package:flutter/material.dart';
import '../models/sub_task.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'round_check.dart';

/// 세부 체크리스트 한 줄.
/// 원형을 누르면 체크/해제, 글자를 누르면 그 자리에서 수정, 오른쪽 X를 누르면 삭제.
class SubTaskRow extends StatefulWidget {
  final SubTask subTask;
  final VoidCallback onToggle;
  final ValueChanged<String> onRename;
  final VoidCallback onDelete;

  const SubTaskRow({
    super.key,
    required this.subTask,
    required this.onToggle,
    required this.onRename,
    required this.onDelete,
  });

  @override
  State<SubTaskRow> createState() => _SubTaskRowState();
}

class _SubTaskRowState extends State<SubTaskRow> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _editing = false;

  @override
  void initState() {
    super.initState();
    // 다른 곳을 누르면(포커스를 잃으면) 저장하고 수정 모드를 끝낸다
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _finish();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEdit() {
    _controller.text = widget.subTask.title;
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  /// 바뀐 내용이 있으면 저장한다. 다 지웠으면 원래 글로 돌아간다.
  void _finish() {
    final value = _controller.text.trim();
    if (value.isNotEmpty && value != widget.subTask.title) {
      widget.onRename(value);
    }
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final sub = widget.subTask;
    final style = text.body.copyWith(
      fontSize: 14,
      decoration: sub.isDone && !_editing ? TextDecoration.lineThrough : null,
      decorationColor: palette.subText,
      color: sub.isDone && !_editing ? palette.subText : palette.titleText,
    );

    return Row(
      children: [
        Semantics(
          button: true,
          label: sub.isDone ? '체크 해제' : '체크',
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onToggle,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 9, 12, 9),
              child: RoundCheck(isDone: sub.isDone, size: 20),
            ),
          ),
        ),
        Expanded(
          child: _editing
              ? TextField(
                  controller: _controller,
                  focusNode: _focus,
                  style: style,
                  scrollPadding: const EdgeInsets.only(bottom: 160),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _focus.unfocus(),
                  decoration: const InputDecoration(
                    isDense: true,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                  ),
                )
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _startEdit,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Text(sub.title, style: style),
                  ),
                ),
        ),
        IconButton(
          onPressed: widget.onDelete,
          tooltip: '세부 항목 삭제',
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.close_rounded, size: 18, color: palette.subText),
        ),
      ],
    );
  }
}
