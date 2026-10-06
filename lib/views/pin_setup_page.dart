import 'package:flutter/material.dart';
import '../services/pin_service.dart';
import '../theme/app_palette.dart';
import '../widgets/pin_sequence.dart';

enum PinSetupMode { enable, change, disable }

/// 설정에서 PIN 켜기·바꾸기·끄기
class PinSetupPage extends StatelessWidget {
  final PinService pin;
  final PinSetupMode mode;

  const PinSetupPage({super.key, required this.pin, required this.mode});

  static Future<bool?> open(BuildContext context, PinService pin, PinSetupMode mode) =>
      Navigator.push<bool>(
        context,
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => PinSetupPage(pin: pin, mode: mode),
        ),
      );

  @override
  Widget build(BuildContext context) {
    const current = PinStepSpec('지금 PIN을 입력해 주세요');
    final (title, steps) = switch (mode) {
      PinSetupMode.enable => (
          'PIN 켜기',
          const [
            PinStepSpec('새 PIN 4자리',
                subtitle: '앱을 열 때마다 이 PIN을 입력해요.\n같은 계정의 모든 기기에 적용돼요.'),
            PinStepSpec('한 번 더 입력해 주세요', confirms: 0),
          ],
        ),
      PinSetupMode.change => (
          'PIN 바꾸기',
          const [
            current,
            PinStepSpec('새 PIN 4자리'),
            PinStepSpec('한 번 더 입력해 주세요', confirms: 1),
          ],
        ),
      PinSetupMode.disable => ('PIN 끄기', const [current]),
    };

    Future<String?> finish(List<String> v) async {
      final error = switch (mode) {
        PinSetupMode.enable => await pin.setPin(v[0]),
        PinSetupMode.change => await pin.setPin(v[1], current: v[0]),
        PinSetupMode.disable => await pin.disable(v[0]),
      };
      if (error == null && context.mounted) Navigator.pop(context, true);
      return error;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: context.palette.background,
        leading: IconButton(
          onPressed: () => Navigator.pop(context, false),
          tooltip: '닫기',
          icon: const Icon(Icons.close_rounded),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: PinSequence(steps: steps, onFinish: finish),
        ),
      ),
    );
  }
}
