import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/local_store.dart';
import '../services/auth_service.dart';
import '../views/login_view.dart';
import 'session_scope.dart';

/// 로그인하지 않으면 로그인 화면만 보여주고, 로그인하면 그 계정의 데이터로 앱을 연다.
/// 계정이 바뀌면 [SessionScope]를 새로 만들어 이전 계정 데이터가 섞이지 않게 한다.
class AuthGate extends StatelessWidget {
  final AuthService? auth;
  final LocalStore? store;
  final Widget child;

  const AuthGate({super.key, this.auth, this.store, required this.child});

  @override
  Widget build(BuildContext context) {
    final store = this.store;
    if (auth == null || store == null) {
      // 테스트·미리보기: 로그인 없이 샘플 데이터
      return SessionScope(store: store, child: child);
    }
    final session = context.watch<AuthService>();
    final user = session.user;
    return switch (session.status) {
      AuthStatus.signedIn when user != null => SessionScope(
          key: ValueKey(user.id),
          store: store.forUser(user.id),
          api: session.api,
          child: child,
        ),
      AuthStatus.checking => const LoginView(checking: true),
      _ => const LoginView(),
    };
  }
}
