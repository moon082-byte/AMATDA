import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/telegram_link.dart';
import '../theme/app_palette.dart';
import '../utils/links.dart';
import 'settings_group.dart';

/// 설정 화면의 '텔레그램 업무방 링크' 줄. 알림 메시지의 [텔레그램 업무방] 줄과 버튼에 쓴다.
/// 텔레그램이 연결돼 있을 때만 보인다.
class TelegramRoomUrlTile extends StatelessWidget {
  const TelegramRoomUrlTile({super.key});

  Future<void> _edit(BuildContext context, TelegramLink link) async {
    final messenger = ScaffoldMessenger.of(context);
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _RoomUrlDialog(link: link),
    );
    if (saved == true) {
      messenger.showSnackBar(SnackBar(
        content: Text(link.roomUrl.isEmpty
            ? '업무방 링크를 지웠어요'
            : '업무방 링크를 저장했어요. 이제 알림에 함께 보내요'),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final link = context.watch<TelegramLink>();
    if (!link.available || !link.linked) return const SizedBox.shrink();
    final palette = context.palette;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _edit(context, link),
      child: SettingsTile(
        icon: Icons.forum_rounded,
        iconColor: link.roomUrl.isEmpty ? palette.subText : palette.accent,
        title: '텔레그램 업무방 링크',
        subtitle: link.roomUrl.isEmpty ? '알림에 넣을 업무방 링크를 입력해 주세요' : link.roomUrl,
        trailing: Icon(Icons.chevron_right_rounded, color: palette.checkboxIdle),
      ),
    );
  }
}

class _RoomUrlDialog extends StatefulWidget {
  final TelegramLink link;

  const _RoomUrlDialog({required this.link});

  @override
  State<_RoomUrlDialog> createState() => _RoomUrlDialogState();
}

class _RoomUrlDialogState extends State<_RoomUrlDialog> {
  late final _controller = TextEditingController(text: widget.link.roomUrl);
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save(String input) async {
    final url = normalizeUrl(input);
    if (url.isNotEmpty && !url.startsWith('http')) {
      setState(() => _error = 'http(s)로 시작하는 주소를 넣어 주세요');
      return;
    }
    setState(() => _saving = true);
    final error = await widget.link.saveRoomUrl(url);
    if (!mounted) return;
    if (error == null) {
      Navigator.pop(context, true);
    } else {
      setState(() {
        _saving = false;
        _error = error;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('텔레그램 업무방 링크'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('리마인드 알림에 [텔레그램 업무방] 링크와 버튼으로 붙여요.\n'
              '같은 계정의 모든 기기에 적용돼요.'),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            keyboardType: TextInputType.url,
            enabled: !_saving,
            decoration: InputDecoration(
              hintText: 'https://t.me/...',
              errorText: _error,
            ),
            onSubmitted: _save,
          ),
        ],
      ),
      actions: [
        if (widget.link.roomUrl.isNotEmpty)
          TextButton(
            onPressed: _saving ? null : () => _save(''),
            child: const Text('지우기'),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: _saving ? null : () => _save(_controller.text),
          child: const Text('저장'),
        ),
      ],
    );
  }
}
