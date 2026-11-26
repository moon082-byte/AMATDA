import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/notion_settings.dart';
import '../services/notion_db_draft.dart';
import '../services/notion_service.dart';
import '../theme/app_palette.dart';
import '../utils/confirm_action.dart';
import '../utils/notion_confirm.dart';
import '../widgets/common/app_page.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/notion_db_section.dart';
import '../widgets/notion_guide.dart';
import '../widgets/notion_status_tile.dart';

/// 노션 연동 설정: 켜기/끄기, 통합 토큰, 할일용·메모용 데이터베이스(링크 → 속성 불러오기 → 매핑), 연동 해제.
class NotionSettingsPage extends StatefulWidget {
  const NotionSettingsPage({super.key});

  @override
  State<NotionSettingsPage> createState() => _NotionSettingsPageState();
}

class _NotionSettingsPageState extends State<NotionSettingsPage> {
  late final NotionService _service = context.read<NotionService>();
  late bool _enabled = _service.enabled;
  final _token = TextEditingController();
  late List<NotionDbDraft> _drafts = NotionDbDraft.all(_service);
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // 다른 기기에서 바꿨을 수 있으니 최신 설정을 받는다
    _service.refresh().then((_) {
      if (!mounted) return;
      setState(() => _enabled = _service.enabled);
      _resetDrafts();
    });
  }

  void _disposeDrafts() {
    for (final d in _drafts) {
      d.dispose();
    }
  }

  /// 저장된 설정으로 다시 채우고, 연결된 데이터베이스는 속성을 읽는다
  void _resetDrafts() {
    _disposeDrafts();
    setState(() => _drafts = NotionDbDraft.all(_service, load: true));
  }

  @override
  void dispose() {
    _token.dispose();
    _disposeDrafts();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() request) async {
    setState(() => _busy = true);
    final message = await runWithMessage(context, request);
    if (!mounted) return;
    setState(() => _busy = false);
    if (message != null) _toast(message);
  }

  void _toast(String message) =>
      ScaffoldMessenger.of(context)..hideCurrentSnackBar()..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _save() async {
    final targets = <NotionTarget, ({String db, NotionMap? map})>{};
    try {
      for (final d in _drafts) {
        if (d.payload() case final p?) targets[d.target] = p;
      }
    } on StateError catch (e) {
      return _toast(e.message);
    }
    await _run(() async {
      await _service.save(enabled: _enabled, token: _token.text, targets: targets);
      _token.clear();
      _resetDrafts();
      return _enabled ? '저장했어요. 이제 노션 데이터베이스에도 반영돼요' : '노션 연동을 껐어요';
    });
  }

  Future<void> _backfill(NotionTarget t) async {
    if (!await confirmNotionBackfill(context, t) || !mounted) return;
    await _run(() async {
      final count = await _service.backfill(t);
      return count == 0 ? '보낼 ${t.label}이(가) 없어요' : '${t.label} $count개를 노션에 보내고 있어요';
    });
  }

  Future<void> _disconnect() async {
    if (!await confirmNotionDisconnect(context) || !mounted) return;
    await _run(() async {
      await _service.disconnect();
      _token.clear();
      setState(() => _enabled = false);
      _resetDrafts();
      return '노션 연동을 해제했어요';
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final service = context.watch<NotionService>();
    return AppPage(
      title: '노션 연동',
      subtitle: '할 일과 메모를 연결할 노션 데이터베이스에도 저장해요',
      slivers: [
        paddedSliver(top: 12, [
          NotionToggleGroup(
              service: service, enabled: _enabled, onChanged: _busy ? null : (v) => setState(() => _enabled = v)),
          const SizedBox(height: 20),
          const NotionGuide(),
          const SizedBox(height: 20),
          LabeledTextField(
            label: '통합 토큰',
            controller: _token,
            hint: service.hasToken ? '저장된 토큰이 있어요 (바꿀 때만 입력)' : 'ntn_… 또는 secret_…',
            obscureText: true,
          ),
          for (final d in _drafts) ...[
            const SizedBox(height: 16),
            NotionDbSection(
              draft: d,
              busy: _busy,
              onLoad: () => d.load(_service, token: _token.text),
              onBackfill: service.enabled && d.connected ? () => _backfill(d.target) : null,
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('저장')),
          if (service.hasToken)
            TextButton(
              onPressed: _busy ? null : _disconnect,
              style: TextButton.styleFrom(foregroundColor: palette.danger),
              child: const Text('연동 해제'),
            ),
        ]),
      ],
    );
  }
}
