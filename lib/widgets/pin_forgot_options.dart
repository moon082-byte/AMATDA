import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../services/pin_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/maybe_provider.dart';

/// PIN을 잊었을 때 고르는 방법
class PinForgotOptions extends StatelessWidget {
  final PinService pin;
  final VoidCallback onTelegram;
  final VoidCallback onFresh;

  const PinForgotOptions({super.key, required this.pin, required this.onTelegram, required this.onFresh});

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
        if (pin.freshLogin)
          FilledButton(onPressed: onFresh, child: const Text('새 PIN 정하기')),
        if (pin.telegram && !pin.freshLogin)
          FilledButton(onPressed: onTelegram, child: const Text('텔레그램으로 재설정 코드 받기')),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: () => maybeProvider<AuthService>(context, listen: false)?.signOut(),
          child: const Text('구글로 다시 로그인하기'),
        ),
      ],
    );
  }
}
