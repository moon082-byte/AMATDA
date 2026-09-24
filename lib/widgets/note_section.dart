import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/date_format.dart';
import 'inline_add_field.dart';

/// 할 일 상세에서 업무 메모를 보여주고 추가하는 섹션
class NoteSection extends StatelessWidget {
  final TaskItem task;

  const NoteSection({super.key, required this.task});

  void _addNote(BuildContext context, String content) {
    final note = Note(
      id: 'note_${DateTime.now().millisecondsSinceEpoch}',
      content: content,
      createdAt: DateTime.now(),
    );
    context.read<RoomProvider>().addNote(task.id, note);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('업무 메모', style: text.label.copyWith(fontSize: 13)),
        const SizedBox(height: 10),
        ...task.notes.map(
          (note) => Container(
            width: double.infinity,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            decoration: BoxDecoration(
              color: palette.warningSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
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
          ),
        ),
        InlineAddField(
          hint: '메모를 남겨보세요',
          onAdd: (value) => _addNote(context, value),
        ),
      ],
    );
  }
}
