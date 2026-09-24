import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import 'due_date_field.dart';
import 'sheet_drag_handle.dart';

/// 기존 할 일의 제목/마감기한을 수정하는 바텀시트를 띄운다
Future<void> showEditTaskSheet(BuildContext context, TaskItem task) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => EditTaskSheet(task: task),
  );
}

class EditTaskSheet extends StatefulWidget {
  final TaskItem task;

  const EditTaskSheet({super.key, required this.task});

  @override
  State<EditTaskSheet> createState() => _EditTaskSheetState();
}

class _EditTaskSheetState extends State<EditTaskSheet> {
  late final TextEditingController _titleController =
      TextEditingController(text: widget.task.title);
  late DateTime? _dueDate = widget.task.dueDate;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: _dueDate != null
          ? TimeOfDay.fromDateTime(_dueDate!)
          : TimeOfDay.now(),
    );
    if (!mounted) return;
    setState(() {
      _dueDate = DateTime(
        date.year,
        date.month,
        date.day,
        time?.hour ?? 0,
        time?.minute ?? 0,
      );
    });
  }

  void _submit() {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;
    final updated = widget.task.copyWithEdits(title: title, dueDate: _dueDate);
    context.read<RoomProvider>().updateTask(updated);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: BoxDecoration(
          color: palette.card,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetDragHandle(),
            const SizedBox(height: 16),
            Text(
              '할 일 수정',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: palette.titleText,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _titleController,
              style: TextStyle(color: palette.titleText),
              decoration: InputDecoration(
                hintText: '할 일을 입력하세요',
                filled: true,
                fillColor: palette.background,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            DueDateField(
              label: '마감 기한',
              value: _dueDate,
              placeholder: '마감 기한 선택 (선택)',
              onTap: _pickDueDate,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                '저장',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
