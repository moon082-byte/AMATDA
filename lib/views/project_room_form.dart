import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/project_room.dart';
import '../services/project_service.dart';
import '../utils/confirm_action.dart';
import '../widgets/common/app_page.dart';
import '../widgets/field_label.dart';
import '../widgets/handle_invite_field.dart';
import '../widgets/labeled_text_field.dart';
import 'project_room_view.dart';

/// 프로젝트방 만들기/수정: 방 이름, 목표, 텔레그램 방 링크 (+ 만들 때 팀원 초대)
class ProjectRoomForm extends StatefulWidget {
  /// 있으면 수정 (팀장만)
  final ProjectRoom? room;

  const ProjectRoomForm({super.key, this.room});

  @override
  State<ProjectRoomForm> createState() => _ProjectRoomFormState();
}

class _ProjectRoomFormState extends State<ProjectRoomForm> {
  late final _name = TextEditingController(text: widget.room?.name ?? '');
  late final _goal = TextEditingController(text: widget.room?.goal ?? '');
  late final _telegram = TextEditingController(text: widget.room?.telegramUrl ?? '');
  final _invitees = <String, String>{}; // userId → 닉네임#태그
  bool _busy = false;

  bool get _isEdit => widget.room != null;

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_name, _goal, _telegram]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final service = context.read<ProjectService>();
    setState(() => _busy = true);
    final room = await runWithMessage(context, () async {
      final fields = (name: _name.text.trim(), goal: _goal.text.trim(), url: _telegram.text.trim());
      if (_isEdit) {
        return service.update(widget.room!.id,
            name: fields.name, goal: fields.goal, telegramUrl: fields.url);
      }
      var created = await service.create(name: fields.name, goal: fields.goal, telegramUrl: fields.url);
      for (final userId in _invitees.keys) {
        created = await service.invite(created.id, userId);
      }
      return created;
    });
    if (!mounted) return;
    setState(() => _busy = false);
    if (room == null) return;
    if (_isEdit) return Navigator.pop(context, room);
    Navigator.pushReplacement(
        context, MaterialPageRoute(builder: (_) => ProjectRoomView(roomId: room.id)));
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = _name.text.trim().isNotEmpty && !_busy;
    return AppPage(
      title: _isEdit ? '프로젝트방 수정' : '프로젝트방 만들기',
      closeIcon: true,
      actions: [saveAction(canSubmit ? _submit : null)],
      slivers: [
        paddedSliver(top: 8, [
          LabeledTextField(label: '프로젝트 이름', controller: _name, hint: '예: 신제품 런칭', autofocus: !_isEdit),
          const SizedBox(height: 24),
          LabeledTextField(label: '프로젝트 목표', controller: _goal, hint: '예: 11월 말까지 베타 출시'),
          const SizedBox(height: 24),
          LabeledTextField(
            label: '텔레그램 방 링크',
            controller: _telegram,
            hint: 'https://t.me/...',
            keyboardType: TextInputType.url,
          ),
          if (!_isEdit) ...[
            const SizedBox(height: 24),
            const FieldLabel('팀원 초대 (수락하면 팀원이 돼요)'),
            HandleInviteField(onFound: (id, handle) => setState(() => _invitees[id] = handle)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final e in _invitees.entries)
                  InputChip(
                    label: Text(e.value),
                    onDeleted: () => setState(() => _invitees.remove(e.key)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 32),
          FilledButton(
            onPressed: canSubmit ? _submit : null,
            child: Text(_busy ? '저장하는 중…' : _isEdit ? '저장하기' : '만들기'),
          ),
        ]),
      ],
    );
  }
}
