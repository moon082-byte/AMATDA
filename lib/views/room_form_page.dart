import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/telegram_room.dart';
import '../providers/room_provider.dart';
import '../utils/ids.dart';
import '../utils/links.dart';
import '../widgets/common/app_page.dart';
import '../widgets/labeled_text_field.dart';
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

  void _removeLink(int index) => setState(() {
        final removed = _links.removeAt(index);
        WidgetsBinding.instance.addPostFrameCallback((_) => removed.dispose());
      });

  void _submit() {
    if (!_canSubmit) return;
    final provider = context.read<RoomProvider>();
    // 새 방이면 빈 방을 만든 뒤, 새 방/기존 방 모두 입력값으로 덮어쓴다.
    // 업무방 자체의 마감·리마인더는 더 쓰지 않으므로(예전 값 포함) 비운다.
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
