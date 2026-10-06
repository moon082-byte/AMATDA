import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../config/bot_config.dart';
import '../data/local_store.dart';
import 'api_client.dart';

/// 로그인한 사용자
class AppUser {
  final String id;
  final String email;
  final String name;
  final String picture;

  /// 주인 계정이면 로그인 도입 전 기기 데이터를 가져올 수 있다
  final bool owner;

  const AppUser({
    required this.id,
    required this.email,
    this.name = '',
    this.picture = '',
    this.owner = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        email: j['email'] as String,
        name: j['name'] as String? ?? '',
        picture: j['picture'] as String? ?? '',
        owner: j['owner'] == true,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'email': email, 'name': name, 'picture': picture, 'owner': owner};
}

enum AuthStatus { checking, signedOut, signedIn }

/// 구글 로그인 상태. 흐름은 bot/src/auth.js 참고:
/// [signIn] → 구글 → 서버 → 앱 주소?login=<일회용 코드> → [init]에서 토큰으로 교환
class AuthService extends ChangeNotifier {
  /// 기기 단위 저장소 (계정 데이터는 [LocalStore.forUser])
  final LocalStore store;
  late final ApiClient api;

  AuthStatus _status = AuthStatus.checking;
  AppUser? _user;
  String? _token;
  String? _error;

  AuthService({
    required this.store,
    http.Client? client,
    String apiUrl = kBotApiUrl,
  }) {
    api = ApiClient(baseUrl: apiUrl, token: () => _token, client: client)
      ..onUnauthorized = _expire;
  }

  AuthStatus get status => _status;
  AppUser? get user => _user;

  /// 로그인 화면에 보여줄 안내 (실패 이유)
  String? get error => _error;

  /// 앱 시작 시: 구글에서 돌아왔으면 코드를 토큰으로 바꾸고, 아니면 저장된 로그인을 확인한다.
  /// 인터넷이 안 되면 저장된 로그인으로 그대로 쓴다.
  Future<void> init({String? loginCode, String? loginError}) async {
    if (loginError != null) _error = _errorMessage(loginError);
    final saved = store.loadSession();
    if (loginCode != null) {
      try {
        final res = await api.post('/auth/exchange', {'code': loginCode});
        return _signedIn(res['token'] as String,
            AppUser.fromJson(res['user'] as Map<String, dynamic>));
      } on ApiException catch (e) {
        _error = e.message;
      }
    }
    if (saved == null) return _set(AuthStatus.signedOut);
    _token = saved.token;
    _user = AppUser.fromJson(saved.user);
    _set(AuthStatus.signedIn);
    try {
      final res = await api.get('/auth/me');
      _signedIn(saved.token, AppUser.fromJson(res['user'] as Map<String, dynamic>));
    } on ApiException catch (_) {
      // 401/403이면 onUnauthorized가 로그아웃시킨다. 오프라인이면 그대로 둔다.
    }
  }

  /// 구글 로그인 화면으로 이동 (이 페이지를 떠났다가 돌아온다)
  Future<void> signIn() async {
    final here = Uri.base;
    final back = '${here.origin}${here.path}';
    final url = Uri.parse('${api.baseUrl}/auth/google/start')
        .replace(queryParameters: {'return': back});
    await launchUrl(url, webOnlyWindowName: '_self');
  }

  Future<void> signOut() async {
    try {
      await api.post('/auth/logout');
    } on ApiException catch (_) {
      // 서버에 못 알려도 이 기기에서는 로그아웃한다
    }
    _expire();
  }

  void _signedIn(String token, AppUser user) {
    _token = token;
    _user = user;
    _error = null;
    store.saveSession(token, user.toJson());
    _set(AuthStatus.signedIn);
  }

  void _expire() {
    _token = null;
    _user = null;
    store.clearSession();
    _set(AuthStatus.signedOut);
  }

  void _set(AuthStatus status) {
    _status = status;
    notifyListeners();
  }

  static String _errorMessage(String code) => switch (code) {
        'not_allowed' => '허용되지 않은 계정이에요. 등록된 구글 계정으로 로그인해 주세요.',
        'cancelled' => '로그인을 취소했어요.',
        _ => '구글 로그인에 실패했어요. 잠시 뒤 다시 시도해 주세요.',
      };
}
