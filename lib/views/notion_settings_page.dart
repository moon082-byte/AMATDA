import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/notion_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/confirm_action.dart';
import '../widgets/common/app_page.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/settings_group.dart';

/// 노션 연동 설정: 켜기/끄기, 통합 토큰, 메모용 DB(1_Inbox) ID·주소, [연결 확인], 연동 해제.
/// 켜 두면 메모를 저장할 때 서버가 노션 1_Inbox에 페이지를 만들고, 고치면 함께 고친다.
class NotionSettingsPage extends StatefulWidget {
  const NotionSettingsPage({super.key});

  @override
  State<NotionSettingsPage> createState() => _NotionSettingsPageState();
}

class _NotionSettingsPageState extends State<NotionSettingsPage> {
  late final NotionService _service = context.read<NotionService>();
  late bool _enabled = _service.enabled;
  final _token = TextEditingController();
  late final _db = TextEditingController(text: _service.memoDb ?? '');
  bool _busy = false;
  bool _touched = false;

  @override
  void initState() {
    super.initState();
    // 다른 기기에서 바꿨을 수 있으니 최신 설정을 받아 (아직 손대지 않았으면) 채운다
    _service.refresh().then((_) {
      if (!mounted || _touched) return;
      setState(() => _enabled = _service.enabled);
      _db.text = _service.memoDb ?? '';
    });
  }

  @override
  void dispose() {
    _token.dispose();
    _db.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() request) async {
    setState(() => _busy = _touched = true);
    final message = await runWithMessage(context, request);
    if (!mounted) return;
    setState(() => _busy = false);
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _check() => _run(() => _service.check(token: _token.text, memoDb: _db.text));

  Future<void> _save() => _run(() async {
        await _service.save(enabled: _enabled, token: _token.text, memoDb: _db.text);
        _token.clear();
        return _enabled ? '노션 연동을 켰어요. 이제 메모가 1_Inbox에 저장돼요' : '노션 연동을 껐어요';
      });

  Future<void> _disconnect() async {
    final ok = await confirmAction(context,
        title: '노션 연동을 해제할까요?',
        message: '저장된 토큰과 DB 설정을 지워요. 이미 만든 노션 페이지는 그대로 남아요.',
        confirmLabel: '해제');
    if (!ok || !mounted) return;
    await _run(() async {
      await _service.disconnect();
      _token.clear();
      _db.clear();
      setState(() => _enabled = false);
      return '노션 연동을 해제했어요';
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final hasToken = context.watch<NotionService>().hasToken;
    return AppPage(
      title: '노션 연동',
      subtitle: '메모를 저장하면 노션 1_Inbox DB에 "정리 대기" 상태로 만들어요',
      slivers: [
        paddedSliver(top: 12, [
          SettingsGroup(title: '연동', children: [
            SettingsTile(
              icon: Icons.sync_rounded,
              iconColor: palette.accent,
              title: '메모를 노션에 저장',
              subtitle: '고치면 노션도 고치고, 지우면 휴지통으로 옮겨요',
              trailing: Switch(
                value: _enabled,
                onChanged: _busy
                    ? null
                    : (v) => setState(() {
                          _touched = true;
                          _enabled = v;
                        }),
              ),
            ),
          ]),
          const SizedBox(height: 24),
          LabeledTextField(
            label: '통합 토큰',
            controller: _token,
            hint: hasToken ? '저장된 토큰이 있어요 (바꿀 때만 입력)' : 'ntn_… 또는 secret_…',
            obscureText: true,
          ),
          const SizedBox(height: 16),
          LabeledTextField(
            label: '메모용 DB ID (또는 DB 주소)',
            controller: _db,
            hint: 'https://www.notion.so/…',
            keyboardType: TextInputType.url,
          ),
          const SizedBox(height: 8),
          Text(
            '1) notion.so/my-integrations에서 내부 통합을 만들고 토큰을 복사해요\n'
            '2) 노션의 1_Inbox DB에서 ⋯ → [연결]에 그 통합을 추가해요\n'
            '3) DB 주소를 붙여 넣고 [연결 확인] 후 [저장]해요',
            style: text.caption,
          ),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: OutlinedButton(onPressed: _busy ? null : _check, child: const Text('연결 확인'))),
            const SizedBox(width: 8),
            Expanded(
              child: FilledButton(onPressed: _busy ? null : _save, child: const Text('저장')),
            ),
          ]),
          if (hasToken) ...[
            const SizedBox(height: 12),
            TextButton(
              onPressed: _busy ? null : _disconnect,
              style: TextButton.styleFrom(foregroundColor: palette.danger),
              child: const Text('연동 해제'),
            ),
          ],
        ]),
      ],
    );
  }
}
