import 'package:flutter/foundation.dart';
import 'api_client.dart';

/// 로그인을 허용한 이메일 한 개
class AllowedEmail {
  final String email;

  /// 서버 설정(비밀값)에 있는 이메일이면 true. 관리자가 잠기지 않도록 화면에서는 지울 수 없다.
  final bool fixed;

  const AllowedEmail(this.email, {this.fixed = false});
}

/// 관리자 전용: 허용 이메일 목록 보기·추가·삭제 (bot/src/admin.js)
class AllowedEmails extends ChangeNotifier {
  static const _path = '/admin/allowed-emails';

  final ApiClient _api;
  List<AllowedEmail> _emails = const [];
  bool _loading = true;
  String? _error;
  bool _disposed = false;

  AllowedEmails(this._api) {
    load();
  }

  List<AllowedEmail> get emails => _emails;
  bool get loading => _loading;

  /// 마지막 요청이 실패한 이유 (성공하면 null)
  String? get error => _error;

  Future<String?> load() => _run(() => _api.get(_path));

  /// 실패하면 이유를 돌려준다
  Future<String?> add(String email) =>
      _run(() => _api.post(_path, {'email': email.trim()}));

  Future<String?> remove(String email) => _run(() =>
      _api.delete('$_path?email=${Uri.encodeQueryComponent(email)}'));

  Future<String?> _run(Future<Map<String, dynamic>> Function() call) async {
    try {
      final res = await call();
      _emails = [
        for (final e in res['emails'] as List)
          AllowedEmail(e['email'] as String, fixed: e['fixed'] == true),
      ];
      _error = null;
    } on ApiException catch (e) {
      _error = e.isOffline ? '인터넷 연결 후 다시 시도해 주세요' : e.message;
    }
    _loading = false;
    if (!_disposed) notifyListeners();
    return _error;
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
