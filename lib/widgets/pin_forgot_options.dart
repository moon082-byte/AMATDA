import 'package:flutter/material.dart';
import '../services/pin_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// PIN을 잊었을 때 고르는 방법: 구글로 다시 로그인(본인 확인 후 바로 새 PIN 입력),
/// 텔레그램이 연결돼 있으면 재설정 코드 받기
class PinForgotOptions extends StatelessWidget {
  final PinService pin;
  final VoidCallback onTelegram;
  final VoidCallback onRelogin;

  const PinForgotOptions({
    super.key,
    required this.pin,
    required this.onTelegram,
    required this.onRelogin,
  });

  @override
  Widget build(BuildContext context) {
    final text = context.text;
    final palette = context.palette;
    return Column(
      children: [
        Text('PIN을 잊으셨나요?', style: text.h2),
        const SizedBox(height: 8),
        Text(
          pin.message ?? '보안을 위해 PIN 번호 자체는 알려드릴 수 없어요.\n본인 확인 후 새 PIN을 정해 주세요.',
          textAlign: TextAlign.center,
          style: text.body.copyWith(color: palette.subText),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: onRelogin,
          child: const Text('구글로 다시 로그인하기'),
        ),
        if (pin.telegram) ...[
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: onTelegram,
            child: const Text('텔레그램으로 재설정 코드 받기'),
          ),
        ],
      ],
    );
  }
}
