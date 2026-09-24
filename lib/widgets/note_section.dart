import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';

/// 할 일 상세에서 업무 메모를 보여주고 추가하는 섹션
class NoteSection extends StatefulWidget {
  final TaskItem task;

  const NoteSection({super.key, required this.task});

  @override
  State<NoteSection> createState() => _NoteSectionState();
}

class _NoteSectionState extends State<NoteSection> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _addNote() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final note = Note(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      content: text,
      createdAt: DateTime.now(),
    );
    context.read<RoomProvider>().addNote(widget.task.id, note);
    _controller.clear();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final task =
        context.watch<RoomProvider>().taskById(widget.task.id) ?? widget.task;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '업무 메모',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: palette.subText,
          ),
        ),
        const SizedBox(height: 8),
        ...task.notes.map(
          (note) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: palette.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              note.content,
              style: TextStyle(fontSize: 13, color: palette.titleText),
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                style: TextStyle(fontSize: 14, color: palette.titleText),
                decoration: InputDecoration(
                  hintText: '메모를 남겨보세요',
                  isDense: true,
                  filled: true,
                  fillColor: palette.background,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
                onSubmitted: (_) => _addNote(),
              ),
            ),
            IconButton(
              onPressed: _addNote,
              icon: Icon(Icons.add_circle, color: palette.accent),
            ),
          ],
        ),
      ],
    );
  }
}
