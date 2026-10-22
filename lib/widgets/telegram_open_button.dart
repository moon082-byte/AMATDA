import 'package:flutter/material.dart';
import '../utils/links.dart';

/// 할 일 상세의 [텔레그램 열기]: 할 일에 단 텔레그램 메시지 링크를 연다 (휴대폰은 텔레그램 앱으로)
class TelegramOpenButton extends StatelessWidget {
  final String link;

  const TelegramOpenButton({super.key, required this.link});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: OutlinedButton.icon(
        onPressed: () => openExternalLink(context, link),
        icon: const Icon(Icons.send_rounded, size: 18),
        label: const Text('텔레그램 열기'),
      ),
    );
  }
}
