import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/telegram_link.dart';
import '../theme/app_palette.dart';
import '../utils/confirm_dialog.dart';
import '../utils/links.dart';
import 'settings_group.dart';

/// 설정 화면의 '텔레그램 알림' 줄: 연결 / 연결 확인 / 연결 끊기
class TelegramLinkTile extends StatelessWidget {
  const TelegramLinkTile({super.key});

  Future<void> _connect(BuildContext context, TelegramLink link) async {
    final messenger = ScaffoldMessenger.of(context);
    final url = link.startUrl();
    if (url == null) {
      messenger.showSnackBar(const SnackBar(
        content: Text('연결을 준비하고 있어요. 잠시 뒤 다시 눌러 주세요'),
      ));
      return;
    }
    await openExternalLink(context, url.toString());
    messenger.showSnackBar(const SnackBar(
      content: Text('텔레그램에서 "시작"을 누른 뒤 이 앱으로 돌아와 주세요'),
      duration: Duration(seconds: 5),
    ));
  }

  Future<void> _check(BuildContext context, TelegramLink link) async {
    final messenger = ScaffoldMessenger.of(context);
    await link.refresh();
    messenger.showSnackBar(SnackBar(
      content: Text(link.linked
          ? '텔레그램과 연결됐어요'
          : '아직 연결되지 않았어요. 텔레그램에서 "시작"을 눌렀는지 확인해 주세요'),
    ));
  }

  Future<void> _disconnect(BuildContext context, TelegramLink link) async {
    final ok = await confirmDelete(
      context,
      '연결을 끊으면 텔레그램으로 리마인드 알림을 받지 않아요.',
    );
    if (ok) await link.disconnect();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final link = context.watch<TelegramLink>();
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: const Size(64, 36),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    );

    final (subtitle, trailing) = !link.available
        ? ('로그인하면 쓸 수 있어요', null)
        : link.linked
            ? (
                '${link.chatName?.isNotEmpty == true ? '${link.chatName}님 ' : ''}텔레그램으로 알려드려요',
                TextButton(
                  onPressed: () => _disconnect(context, link),
                  style: TextButton.styleFrom(foregroundColor: palette.danger),
                  child: const Text('연결 끊기'),
                ),
              )
            : link.pending
                ? (
                    '텔레그램에서 "시작"을 누르면 연결돼요',
                    FilledButton(
                      onPressed: () => _check(context, link),
                      style: buttonStyle,
                      child: const Text('연결 확인'),
                    ),
                  )
                : (
                    '앱을 닫아 둬도 텔레그램으로 리마인드를 받아요',
                    FilledButton(
                      onPressed: () => _connect(context, link),
                      style: buttonStyle,
                      child: const Text('연결'),
                    ),
                  );

    final tile = SettingsTile(
      icon: Icons.send_rounded,
      iconColor: link.linked ? palette.accent : palette.subText,
      title: '텔레그램 알림',
      subtitle: subtitle,
      trailing: trailing,
    );
    if (!link.pending) return tile;
    // 연결 대기 중이면 텔레그램을 다시 열 수 있게 한다
    return Column(
      children: [
        tile,
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: () => _connect(context, link),
            child: const Text('텔레그램 다시 열기'),
          ),
        ),
      ],
    );
  }
}
