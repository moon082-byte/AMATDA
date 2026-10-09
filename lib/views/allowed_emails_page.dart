import 'package:flutter/material.dart';
import '../services/allowed_emails.dart';
import '../services/api_client.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/confirm_dialog.dart';
import '../widgets/common/app_page.dart';
import '../widgets/settings_group.dart';

/// 관리자 전용: 로그인을 허용할 이메일 추가·삭제
class AllowedEmailsPage extends StatefulWidget {
  final ApiClient api;

  const AllowedEmailsPage({super.key, required this.api});

  @override
  State<AllowedEmailsPage> createState() => _AllowedEmailsPageState();
}

class _AllowedEmailsPageState extends State<AllowedEmailsPage> {
  late final _list = AllowedEmails(widget.api);
  final _input = TextEditingController();

  @override
  void dispose() {
    _list.dispose();
    _input.dispose();
    super.dispose();
  }

  Future<void> _add() async {
    if (_input.text.trim().isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final error = await _list.add(_input.text);
    if (error == null) _input.clear();
    messenger.showSnackBar(SnackBar(content: Text(error ?? '추가했어요. 이제 이 이메일로 로그인할 수 있어요')));
  }

  Future<void> _remove(String email) async {
    final ok = await confirmDelete(context, '$email 계정은 바로 쓸 수 없게 돼요.\n데이터는 남아 있어서 다시 추가하면 그대로 볼 수 있어요.');
    if (!ok || !mounted) return;
    final error = await _list.remove(email);
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;

    return ListenableBuilder(
      listenable: _list,
      builder: (context, _) => AppPage(
        title: '허용 이메일 관리',
        subtitle: '여기 등록한 구글 계정만 아맞다에 로그인할 수 있어요.',
        slivers: [
          paddedSliver(top: 12, [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _input,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(hintText: '추가할 구글 이메일'),
                    onSubmitted: (_) => _add(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _add,
                  // 앱 기본 버튼은 가로를 꽉 채우므로 줄 안에서는 크기를 정해 준다
                  style: FilledButton.styleFrom(minimumSize: const Size(72, 48)),
                  child: const Text('추가'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '구글 로그인이 아직 "테스트 중"이면 Google Cloud Console → Google Auth Platform → '
              '대상 → 테스트 사용자에도 같은 이메일을 추가해야 해요.',
              style: text.micro.copyWith(color: palette.subText),
            ),
            const SizedBox(height: 24),
            if (_list.loading)
              const Center(child: CircularProgressIndicator())
            else if (_list.error != null && _list.emails.isEmpty)
              Text(_list.error!, style: text.caption.copyWith(color: palette.danger))
            else
              SettingsGroup(
                title: '허용된 이메일 ${_list.emails.length}개',
                children: [
                  for (final e in _list.emails)
                    SettingsTile(
                      icon: Icons.person_rounded,
                      iconColor: e.fixed ? palette.accent : palette.subText,
                      title: e.email,
                      subtitle: e.fixed ? '서버 설정 · 여기서 지울 수 없어요' : null,
                      trailing: e.fixed
                          ? null
                          : IconButton(
                              onPressed: () => _remove(e.email),
                              tooltip: '${e.email} 삭제',
                              icon: Icon(Icons.delete_outline_rounded, color: palette.danger),
                            ),
                    ),
                ],
              ),
          ]),
        ],
      ),
    );
  }
}
