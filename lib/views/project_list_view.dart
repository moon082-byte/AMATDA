import 'package:flutter/material.dart';
import '../models/project_room_page.dart';
import '../services/project_service.dart';
import '../theme/app_typography.dart';
import '../utils/confirm_action.dart';
import '../utils/maybe_provider.dart';
import '../widgets/common/empty_state.dart';
import '../widgets/project_invite_card.dart';
import '../widgets/project_room_tile.dart';
import 'project_room_form.dart';
import 'project_room_view.dart';

/// [프로젝트] 탭: 받은 초대, 내가 참여 중인 프로젝트방 (10개씩, 넘으면 다음 페이지), [방 만들기]
class ProjectListView extends StatefulWidget {
  const ProjectListView({super.key});

  @override
  State<ProjectListView> createState() => _ProjectListViewState();
}

class _ProjectListViewState extends State<ProjectListView> {
  late final ProjectService? _service = maybeProvider<ProjectService>(context, listen: false);
  ProjectRoomPage? _data;
  int _page = 1;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load([int? page]) async {
    final service = _service;
    if (service == null) return;
    final data = await runWithMessage(context, () => service.list(page: page ?? _page));
    if (!mounted) return;
    if (data == null) return setState(() => _failed = _data == null);
    setState(() {
      _failed = false;
      _data = data;
      _page = data.page;
    });
  }

  /// 방 화면이나 만들기 화면을 열고, 돌아오면 목록을 새로 받는다
  Future<void> _open(Widget page, {bool fullscreen = false}) async {
    await Navigator.push(
        context, MaterialPageRoute(fullscreenDialog: fullscreen, builder: (_) => page));
    _load();
  }

  Future<void> _answer(ProjectInvite invite, bool accept) async {
    final service = _service!;
    final ok = await runWithMessage(context, () async {
      accept ? await service.accept(invite.roomId) : await service.decline(invite.roomId);
      return true;
    });
    if (ok == true && accept) return _open(ProjectRoomView(roomId: invite.roomId));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final data = _data;
    return Scaffold(
      floatingActionButton: _service == null
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _open(const ProjectRoomForm(), fullscreen: true),
              icon: const Icon(Icons.add_rounded),
              label: const Text('방 만들기'),
            ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
            children: [
              Text('프로젝트', style: text.h1),
              const SizedBox(height: 20),
              if (_service == null)
                const EmptyState(icon: Icons.groups_rounded, title: '로그인하면 팀 프로젝트를 쓸 수 있어요')
              else if (data == null && _failed)
                Column(children: [
                  const EmptyState(icon: Icons.cloud_off_rounded, title: '프로젝트 목록을 불러오지 못했어요'),
                  OutlinedButton(onPressed: _load, child: const Text('다시 시도')),
                ])
              else if (data == null)
                const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
              else ...[
                for (final invite in data.invites) ProjectInviteCard(invite: invite, onAnswer: _answer),
                if (data.rooms.isEmpty)
                  const EmptyState(
                    icon: Icons.groups_rounded,
                    title: '참여 중인 프로젝트방이 없어요',
                    message: '[방 만들기]로 팀원을 초대해 함께 업무를 나눠 보세요',
                  ),
                for (final room in data.rooms)
                  ProjectRoomTile(room: room, onTap: () => _open(ProjectRoomView(roomId: room.id))),
                if (data.pageCount > 1)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: _page > 1 ? () => _load(_page - 1) : null,
                        tooltip: '이전 페이지',
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Text('$_page / ${data.pageCount}', style: text.body),
                      IconButton(
                        onPressed: _page < data.pageCount ? () => _load(_page + 1) : null,
                        tooltip: '다음 페이지',
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
