import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/telegram_room.dart';
import '../providers/room_provider.dart';
import '../utils/pick_date_time.dart';
import 'common/app_sheet.dart';
import 'due_date_field.dart';
import 'field_label.dart';
import 'labeled_text_field.dart';
import 'reminder_chip_selector.dart';

/// 새 업무방 추가 바텀시트를 띄운다
Future<void> showCreateRoomSheet(BuildContext context) {
  return showAppSheet(context, (_) => const CreateRoomSheet());
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
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _linkController.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await pickDateTime(context, initial: _dueDate);
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    context.read<RoomProvider>().addRoom(TelegramRoom(
          id: 'room_${DateTime.now().millisecondsSinceEpoch}',
          name: name,
          type: TelegramRoomType.group,
          inviteLink: _linkController.text.trim(),
          lastActivityAt: DateTime.now(),
          dueDate: _dueDate,
          reminderOption: _reminder,
        ));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: '새 업무방 만들기',
      subtitle: '텔레그램 방과 연결해 할 일을 모아서 관리해요',
      primaryLabel: '만들기',
      onPrimary: _nameController.text.trim().isEmpty ? null : _submit,
      children: [
        LabeledTextField(
          label: '방 제목',
          controller: _nameController,
          hint: '예: 마케팅팀 프로젝트',
          autofocus: true,
        ),
        const SizedBox(height: 20),
        LabeledTextField(
          label: '텔레그램 방 링크',
          controller: _linkController,
          hint: 'https://t.me/...',
          keyboardType: TextInputType.url,
        ),
        const SizedBox(height: 20),
        DueDateField(
          label: '마감 기한',
          value: _dueDate,
          placeholder: '마감 기한 선택 (선택)',
          onTap: _pickDueDate,
          onClear: () => setState(() => _dueDate = null),
        ),
        const SizedBox(height: 20),
        const FieldLabel('리마인더 알림'),
        ReminderChipSelector(
          selected: _reminder,
          onSelected: (option) => setState(() => _reminder = option),
        ),
      ],
    );
  }
}
