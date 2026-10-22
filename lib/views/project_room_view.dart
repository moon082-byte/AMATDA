import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/project_room.dart';
import '../providers/room_provider.dart';
import '../services/project_service.dart';
import '../theme/app_palette.dart';
import '../utils/confirm_action.dart';
import '../utils/confirm_dialog.dart';
import '../utils/links.dart';
import '../widgets/common/app_page.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/project_room_body.dart';
import '../widgets/task_row_actions.dart';
import 'project_room_form.dart';
import 'project_room_header.dart';
import 'project_edit_actions.dart';

/// 프로젝트방 화면: "할 일 N개가 남아있어요"·목표, 달력·오늘의 일정, [프로젝트][팀원] 탭. 팀장은 편집·팀원 관리.
class ProjectRoomView extends StatefulWidget {
  final String roomId;

  const ProjectRoomView({super.key, required this.roomId});

  @override
  State<ProjectRoomView> createState() => _ProjectRoomViewState();
}

class _ProjectRoomViewState extends State<ProjectRoomView> {
  late final ProjectService _service = context.read<ProjectService>();
  ProjectRoom? _room;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final room = await runWithMessage(context, () => _service.detail(widget.roomId));
    if (mounted) setState(() => room == null ? _missing = _room == null : _room = room);
  }

  Future<void> _apply(Future<ProjectRoom> Function() request) async {
    final room = await runWithMessage(context, request);
    if (room != null && mounted) setState(() => _room = room);
  }

  ProjectEditActions get _edits =>
      ProjectEditActions(context: context, service: _service, apply: _apply);

  Future<void> _roomMenu(ProjectRoom room, String action) async {
    if (action == 'edit') {
      final updated = await Navigator.push<ProjectRoom>(context,
          MaterialPageRoute(fullscreenDialog: true, builder: (_) => ProjectRoomForm(room: room)));
      if (updated != null && mounted) setState(() => _room = updated);
    } else if (await confirmDelete(context, '"${room.name}"방의 프로젝트·업무가 모두 삭제돼요.')) {
      if (!mounted) return;
      final ok = await runWithMessage(context, () async {
        await _service.delete(room.id);
        return true;
      });
      if (ok == true && mounted) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = _room;
    if (room == null) {
      return Scaffold(
        appBar: AppBar(),
        body: _missing
            ? const EmptyState(icon: Icons.search_off_rounded, title: '프로젝트방을 찾을 수 없어요')
            : const Center(child: CircularProgressIndicator()),
      );
    }
    final palette = context.palette;
    final rooms = context.watch<RoomProvider>();
    return AppPage(
      title: room.name,
      actions: [
        if (room.telegramUrl.isNotEmpty)
          IconButton(
            onPressed: () => openExternalLink(context, room.telegramUrl),
            tooltip: '텔레그램 방 열기',
            icon: Icon(Icons.send_rounded, color: palette.bodyText),
          ),
        if (room.isLeader)
          PopupMenuButton<String>(
            tooltip: '방 관리',
            onSelected: (a) => _roomMenu(room, a),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('방 수정')),
              PopupMenuItem(value: 'delete', child: Text('방 삭제')),
            ],
          ),
      ],
      floatingActionButton: room.isLeader
          ? FloatingActionButton.extended(
              onPressed: () => _edits.editProject(room),
              icon: const Icon(Icons.add_rounded),
              label: const Text('프로젝트 추가'),
            )
          : null,
      slivers: [
        paddedSliver(top: 4, [
          ProjectRoomHeader(
            room: room,
            onAccept: () => _apply(() => _service.accept(room.id)),
            onDecline: () async {
              await runWithMessage(context, () => _service.decline(room.id));
              if (context.mounted) Navigator.pop(context);
            },
          ),
          const SizedBox(height: 20),
          ProjectRoomBody(
            room: room,
            actions: TaskRowActions(
              room: room,
              status: (t) => _edits.status(room, t),
              remind: _edits.remind,
              rename: _edits.rename,
              edit: (t) => _edits.editTask(room, room.projectOf(t), t),
              delete: _edits.deleteTask,
              reminderCount: (t) => rooms.taskById(ProjectEditActions.mirrorId(t))?.remindAt.length ?? 0,
            ),
            onEditProject: (p) => _edits.editProject(room, p),
            onDeleteProject: _edits.deleteProject,
            onInvite: (userId) => _edits.invite(room, userId),
            onRemoveMember: (m) => _edits.removeMember(room, m),
            onAddTask: (p) => _edits.editTask(room, p),
          ),
        ]),
      ],
    );
  }
}
