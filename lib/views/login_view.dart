import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// 로그인 화면. 로그인하지 않으면 앱의 다른 화면과 데이터에 접근할 수 없다.
/// [checking]이면 저장된 로그인을 확인하는 중이라 버튼 대신 진행 표시를 보여준다.
class LoginView extends StatelessWidget {
  final bool checking;

  const LoginView({super.key, this.checking = false});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final auth = context.watch<AuthService>();
    final error = auth.error;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 24, 28, 32),
          child: Column(
            children: [
              const Spacer(flex: 3),
              const _AppMark(),
              const SizedBox(height: 22),
              Text('아맞다', style: text.h1),
              const SizedBox(height: 8),
              Text(
                '텔레그램 업무방과 할 일·루틴을 챙겨 주는\n업무 리마인더',
                textAlign: TextAlign.center,
                style: text.body.copyWith(color: palette.subText),
              ),
              const Spacer(flex: 4),
              if (error != null && !checking)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Text(
                    error,
                    textAlign: TextAlign.center,
                    style: text.caption.copyWith(color: palette.danger),
                  ),
                ),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: checking
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton.icon(
                        onPressed: auth.signIn,
                        icon: const Icon(Icons.login_rounded),
                        label: const Text('Google 계정으로 로그인'),
                      ),
              ),
              const SizedBox(height: 14),
              Text(
                '등록된 계정만 사용할 수 있어요.\n같은 계정으로 로그인하면 휴대폰과 PC의 데이터가 함께 맞춰져요.',
                textAlign: TextAlign.center,
                style: text.micro.copyWith(color: palette.subText),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 앱 아이콘 모양 로고
class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      width: 96,
      height: 96,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: palette.accent,
        borderRadius: BorderRadius.circular(26),
      ),
      child: const Text(
        '아',
        style: TextStyle(
          color: Colors.white,
          fontSize: 44,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
