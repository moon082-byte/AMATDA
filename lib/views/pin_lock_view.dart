import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/pin_service.dart';
import '../theme/app_palette.dart';
import '../utils/maybe_provider.dart';
import '../widgets/pin_forgot_options.dart';
import '../widgets/pin_sequence.dart';

enum _Mode { verify, forgot, resetWithCode, resetFresh }

/// 앱을 열 때 나오는 PIN 입력 화면. 잊었으면 텔레그램 코드나 구글 재로그인으로 새로 정한다.
class PinLockView extends StatefulWidget {
  const PinLockView({super.key});

  @override
  State<PinLockView> createState() => _PinLockViewState();
}

class _PinLockViewState extends State<PinLockView> {
  _Mode _mode = _Mode.verify;
  Timer? _ticker;
  String? _note;

  @override
  void initState() {
    super.initState();
    // 잠금 남은 시간을 1초마다 다시 그린다
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final until = context.read<PinService>().lockedUntil;
      if (until != null && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  String? _lockText(PinService pin) {
    final until = pin.lockedUntil;
    if (until == null) return null;
    final left = until.difference(DateTime.now());
    if (left.isNegative) return null;
    final m = left.inMinutes;
    final s = (left.inSeconds % 60).toString().padLeft(2, '0');
    return '잘못 입력해서 잠겼어요. $m:$s 뒤에 다시 입력할 수 있어요';
  }

  Future<void> _sendCode(PinService pin) async {
    final error = await pin.sendResetCode();
    if (!mounted) return;
    setState(() {
      _note = error ?? '텔레그램으로 6자리 재설정 코드를 보냈어요';
      if (error == null) _mode = _Mode.resetWithCode;
    });
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final pin = context.watch<PinService>();
    final lock = _lockText(pin);
    final offline = pin.status == PinStatus.offline;

    final Widget body = switch (_mode) {
      _Mode.verify => PinSequence(
          key: const ValueKey('verify'),
          steps: [PinStepSpec('PIN을 입력해 주세요', subtitle: maybeProvider<AuthService>(context, listen: false)?.user?.email)],
          error: offline
              ? pin.message
              : lock ?? _remainingText(pin) ?? (pin.lockedUntil == null ? pin.message : null),
          enabled: !offline && lock == null,
          // 틀린 이유(남은 횟수·잠금)는 위 error가 PIN 상태에서 직접 보여준다
          onFinish: (v) async {
            await pin.verify(v[0]);
            return null;
          },
        ),
      _Mode.forgot => PinForgotOptions(
          pin: pin,
          onTelegram: () => _sendCode(pin),
          onFresh: () => setState(() => _mode = _Mode.resetFresh),
        ),
      _Mode.resetWithCode => PinSequence(
          key: const ValueKey('code'),
          steps: [
            PinStepSpec('재설정 코드', subtitle: _note, length: 6),
            const PinStepSpec('새 PIN 4자리'),
            const PinStepSpec('새 PIN 한 번 더', confirms: 1),
          ],
          onFinish: (v) => pin.reset(v[1], code: v[0]),
        ),
      _Mode.resetFresh => PinSequence(
          key: const ValueKey('fresh'),
          steps: const [PinStepSpec('새 PIN 4자리'), PinStepSpec('새 PIN 한 번 더', confirms: 0)],
          onFinish: (v) => pin.reset(v[0]),
        ),
    };

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_rounded, size: 36, color: palette.accent),
                const SizedBox(height: 16),
                body,
                const SizedBox(height: 12),
                if (offline)
                  TextButton(onPressed: pin.load, child: const Text('다시 시도'))
                else if (_mode == _Mode.verify)
                  TextButton(
                    onPressed: () => setState(() => _mode = _Mode.forgot),
                    child: const Text('PIN을 잊었어요'),
                  )
                else
                  TextButton(
                    onPressed: () => setState(() => _mode = _Mode.verify),
                    child: const Text('PIN 입력으로 돌아가기'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static String? _remainingText(PinService pin) {
    final left = pin.remaining;
    return left != null && left < 5 ? '${pin.message ?? 'PIN이 맞지 않아요'} (남은 횟수 $left번)' : null;
  }
}
