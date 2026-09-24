import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/telegram_room.dart';
import '../providers/room_provider.dart';
import '../theme/app_palette.dart';
import 'due_date_field.dart';
import 'field_label.dart';
import 'labeled_text_field.dart';
import 'reminder_chip_selector.dart';
import 'sheet_drag_handle.dart';

/// 새 업무방 추가 바텀시트를 띄운다
Future<void> showCreateRoomSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const CreateRoomSheet(),
  );
}

class CreateRoomSheet extends StatefulWidget {
  const CreateRoomSheet({super.key});

  @override
  State<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends State<CreateRoomSheet> {
  final _nameController = TextEditingController();
  final _linkController = TextEditingController();
  DateTime? _dueDate;
  ReminderOption _reminder = ReminderOption.none;

  @override
  void dispose() {
    _nameController.dispose();
    _linkController.dispose();
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
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final room = TelegramRoom(
      id: 'room_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      type: TelegramRoomType.group,
      inviteLink: _linkController.text.trim(),
      lastActivityAt: DateTime.now(),
      dueDate: _dueDate,
      reminderOption: _reminder,
    );
    context.read<RoomProvider>().addRoom(room);
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
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetDragHandle(),
              const SizedBox(height: 16),
              Text(
                '새 업무방 만들기',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: palette.titleText,
                ),
              ),
              const SizedBox(height: 20),
              LabeledTextField(
                label: '방 제목',
                controller: _nameController,
                hint: '예: 마케팅팀 프로젝트',
              ),
              const SizedBox(height: 16),
              LabeledTextField(
                label: '텔레그램 방 링크',
                controller: _linkController,
                hint: 'https://t.me/...',
              ),
              const SizedBox(height: 16),
              DueDateField(
                label: '마감 기한',
                value: _dueDate,
                placeholder: '마감 기한 선택',
                onTap: _pickDueDate,
              ),
              const SizedBox(height: 16),
              const FieldLabel('리마인더 알림'),
              ReminderChipSelector(
                selected: _reminder,
                onSelected: (option) => setState(() => _reminder = option),
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
                  '만들기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
