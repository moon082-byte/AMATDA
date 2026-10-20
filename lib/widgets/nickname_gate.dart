import 'package:flutter/material.dart';
import '../services/profile_service.dart';
import '../utils/maybe_provider.dart';
import '../views/nickname_setup_view.dart';

/// 로그인·PIN 다음 관문: 처음 로그인해 닉네임이 없으면 닉네임 설정 화면을 먼저 보여준다.
/// 서버에 닿지 않으면(오프라인) 막지 않고 앱을 연다.
class NicknameGate extends StatelessWidget {
  final Widget child;

  const NicknameGate({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final profile = maybeProvider<ProfileService>(context);
    if (profile == null) return child;
    if (profile.status == ProfileStatus.loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!profile.needsNickname) return child;
    // 앱 화면(Navigator) 밖이라 입력칸이 쓸 Overlay를 갖도록 작은 Navigator로 감싼다
    return Navigator(
      onGenerateRoute: (_) =>
          MaterialPageRoute(builder: (_) => const NicknameSetupView()),
    );
  }
}
