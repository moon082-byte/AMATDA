import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_item.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import 'due_date_field.dart';
import 'sheet_drag_handle.dart';

/// 특정 업무방에 새 할 일을 추가하는 바텀시트를 띄운다
Future<void> showAddTaskSheet(BuildContext context, String roomId) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => AddTaskSheet(roomId: roomId),
  );
}

class AddTaskSheet extends StatefulWidget {
  final String roomId;

  const AddTaskSheet({super.key, required this.roomId});

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _titleController = TextEditingController();
  DateTime? _dueDate;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 1)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
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

    final task = TaskItem(
      id: 'task_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      dueDate: _dueDate,
      roomId: widget.roomId,
      createdAt: DateTime.now(),
    );
    context.read<RoomProvider>().addTask(task);
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
              '할 일 추가',
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
                '추가',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
