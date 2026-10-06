import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/task_reminder.dart';
import '../models/telegram_room.dart';
import '../providers/room_provider.dart';
import '../utils/ids.dart';
import '../utils/links.dart';
import '../utils/pick_date_time.dart';
import '../widgets/common/app_page.dart';
import '../widgets/due_date_field.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/reminder_list_editor.dart';
import '../widgets/room_info_fields.dart';
import '../widgets/work_links_field.dart';

/// 업무방 만들기/수정 공용 입력 화면. [room]이 있으면 수정 모드로 동작한다.
class RoomFormPage extends StatefulWidget {
  final TelegramRoom? room;

  const RoomFormPage({super.key, this.room});

  @override
  State<RoomFormPage> createState() => _RoomFormPageState();
}

class _RoomFormPageState extends State<RoomFormPage> {
  late final _name = TextEditingController(text: widget.room?.name ?? '');
  late final _telegram =
      TextEditingController(text: widget.room?.inviteLink ?? '');
  late final List<TextEditingController> _links = [
    for (final link in widget.room?.workLinks ?? const <String>[])
      TextEditingController(text: link),
  ];
  late DateTime? _dueDate = widget.room?.dueDate;
  late List<TaskReminder> _reminders = widget.room?.reminders ?? const [];
  late TelegramRoomType _type = widget.room?.type ?? TelegramRoomType.group;
  late int _memberCount = widget.room?.memberCount ?? 1;

  bool get _isEdit => widget.room != null;
  bool get _canSubmit => _name.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _telegram, ..._links]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final picked = await pickDateTime(context, initial: _dueDate);
    if (picked != null && mounted) setState(() => _dueDate = picked);
  }

  void _removeLink(int index) => setState(() {
        final removed = _links.removeAt(index);
        WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
      });

  void _submit() {
    if (!_canSubmit) return;
    final provider = context.read<RoomProvider>();
    // 새 방이면 빈 방을 만든 뒤, 새 방/기존 방 모두 입력값으로 덮어쓴다
    final base = widget.room ??
        TelegramRoom(
          id: newId('room'),
          name: '',
          type: _type,
          inviteLink: '',
          lastActivityAt: DateTime.now(),
        );
    final room = base.copyWithEdits(
      name: _name.text.trim(),
      type: _type,
      memberCount: _memberCount,
      inviteLink: normalizeUrl(_telegram.text),
      workLinks: cleanLinks(_links.map((c) => c.text)),
      dueDate: _dueDate,
      reminders: _dueDate == null ? const [] : _reminders,
    );
    _isEdit ? provider.updateRoom(room) : provider.addRoom(room);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: _isEdit ? '업무방 수정' : '새 업무방 만들기',
      subtitle: _isEdit ? null : '텔레그램 방과 연결해 할 일을 모아서 관리해요',
      closeIcon: true,
      actions: [saveAction(_canSubmit ? _submit : null)],
      slivers: [
        paddedSliver(top: 12, [
          LabeledTextField(
            label: '방 제목',
            controller: _name,
            hint: '예: 마케팅팀 프로젝트',
            autofocus: !_isEdit,
          ),
          const SizedBox(height: 24),
          RoomInfoFields(
            type: _type,
            memberCount: _memberCount,
            onTypeChanged: (t) => setState(() => _type = t),
            onMemberCountChanged: (n) => setState(() => _memberCount = n),
          ),
          const SizedBox(height: 24),
          LabeledTextField(
            label: '텔레그램 방 링크',
            controller: _telegram,
            hint: 'https://t.me/...',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 24),
          WorkLinksField(
            controllers: _links,
            onAdd: () => setState(() => _links.add(TextEditingController())),
            onRemove: _removeLink,
          ),
          const SizedBox(height: 24),
          DueDateField(
            label: '마감 기한',
            value: _dueDate,
            placeholder: '마감 기한 선택 (선택)',
            onTap: _pickDueDate,
            onClear: () => setState(() => _dueDate = null),
          ),
          const SizedBox(height: 24),
          ReminderListEditor(
            label: '리마인더 알림',
            dueDate: _dueDate,
            value: _reminders,
            onChanged: (r) => setState(() => _reminders = r),
          ),
          const SizedBox(height: 32),
          FilledButton(
            onPressed: _canSubmit ? _submit : null,
            child: Text(_isEdit ? '저장하기' : '만들기'),
          ),
        ]),
      ],
    );
  }
}
