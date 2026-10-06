import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/note.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import '../theme/app_typography.dart';
import '../utils/confirm_dialog.dart';
import '../utils/ids.dart';
import 'inline_add_field.dart';
import 'note_tile.dart';

/// 할 일 상세에서 업무 메모를 보여주고 추가하는 섹션.
/// 메모를 왼쪽으로 밀면 수정/삭제 버튼이 나온다.
class NoteSection extends StatelessWidget {
  final TaskItem task;

  const NoteSection({super.key, required this.task});

  void _addNote(BuildContext context, String content) {
    final note = Note(
      id: newId('note'),
      content: content,
      createdAt: DateTime.now(),
    );
    context.read<RoomProvider>().addNote(task.id, note);
  }

  Future<void> _deleteNote(BuildContext context, Note note) async {
    final confirmed = await confirmDelete(context, '이 메모를 삭제할까요?');
    if (!context.mounted || !confirmed) return;
    context.read<RoomProvider>().deleteNote(task.id, note.id);
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final provider = context.read<RoomProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('업무 메모', style: text.label.copyWith(fontSize: 13)),
        const SizedBox(height: 10),
        for (final note in task.notes)
          NoteTile(
            key: ValueKey(note.id),
            note: note,
            onSave: (content) => provider.updateNote(task.id, note.id, content),
            onDelete: () => _deleteNote(context, note),
          ),
        InlineAddField(
          hint: '메모를 남겨보세요',
          onAdd: (value) => _addNote(context, value),
        ),
      ],
    );
  }
}
