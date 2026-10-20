import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/profile.dart';
import '../models/project_room.dart';
import '../services/project_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/confirm_action.dart';
import 'handle_invite_field.dart';
import 'profile_avatar.dart';
import 'sheet_drag_handle.dart';

/// 팀원 목록 시트. 팀장은 닉네임#태그로 초대하고, 팀원을 내보내거나 초대를 취소할 수 있다.
/// 방이 바뀌면 [onChanged]로 새 방 상세를 알려 준다.
Future<void> showMembersSheet(BuildContext context, ProjectRoom room,
    ValueChanged<ProjectRoom> onChanged) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => _MembersSheet(room: room, onChanged: onChanged),
  );
}

class _MembersSheet extends StatefulWidget {
  final ProjectRoom room;
  final ValueChanged<ProjectRoom> onChanged;

  const _MembersSheet({required this.room, required this.onChanged});

  @override
  State<_MembersSheet> createState() => _MembersSheetState();
}

class _MembersSheetState extends State<_MembersSheet> {
  late ProjectRoom _room = widget.room;

  Future<void> _apply(Future<ProjectRoom> Function() request) async {
    final room = await runWithMessage(context, request);
    if (room == null || !mounted) return;
    setState(() => _room = room);
    widget.onChanged(room);
  }

  Future<void> _remove(String userId, String handle, bool invited) async {
    final ok = await confirmAction(
      context,
      title: invited ? '초대를 취소할까요?' : '$handle님을 내보낼까요?',
      message: invited ? null : '맡고 있던 진행 중 업무는 담당자 없음으로 바뀌어요.',
      confirmLabel: invited ? '초대 취소' : '내보내기',
    );
    if (!ok || !mounted) return;
    final service = context.read<ProjectService>();
    await _apply(() => service.removeMember(_room.id, userId));
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final service = context.read<ProjectService>();

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 12, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetDragHandle(),
            const SizedBox(height: 16),
            Text('팀원 ${_room.activeMembers.length}명', style: text.h2),
            const SizedBox(height: 12),
            for (final m in _room.members)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: ProfileAvatar(profile: Profile(nickname: m.nickname), size: 36),
                title: Text(m.handle),
                subtitle: Text(m.isLeader ? '팀장' : m.invited ? '초대 중 · 수락을 기다려요' : '팀원',
                    style: text.caption.copyWith(color: m.isLeader ? palette.accent : null)),
                trailing: _room.isLeader && !m.isLeader
                    ? IconButton(
                        onPressed: () => _remove(m.userId, m.handle, m.invited),
                        tooltip: m.invited ? '초대 취소' : '내보내기',
                        icon: Icon(Icons.person_remove_rounded, color: palette.danger),
                      )
                    : null,
              ),
            if (_room.isLeader) ...[
              const SizedBox(height: 12),
              HandleInviteField(
                onFound: (userId, _) => _apply(() => service.invite(_room.id, userId)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
