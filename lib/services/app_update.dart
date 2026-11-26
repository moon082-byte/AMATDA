import 'dart:async';
import 'dart:convert';
import 'package:flutter/widgets.dart';
import 'package:http/http.dart' as http;
import 'page_reload.dart';

/// 이 앱의 빌드 번호 (배포할 때 --dart-define=BUILD_ID=<커밋>으로 넣는다. 개발·테스트에서는 비어 있다)
const appBuildId = String.fromEnvironment('BUILD_ID');

/// 새 버전 감지: 배포된 build.json의 빌드 번호가 지금 앱과 다르면 [available]이 된다.
/// 앱을 켤 때, 앱으로 돌아올 때, 30분마다 확인한다. [새로고침]하면 최신 버전을 다시 불러온다.
class AppUpdate extends ChangeNotifier {
  final String current;
  final http.Client _client;
  Timer? _timer;
  AppLifecycleListener? _life;

  /// 새 버전이 배포됐는지
  bool available = false;
  String? latest;

  AppUpdate({this.current = appBuildId, http.Client? client}) : _client = client ?? http.Client();

  /// 빌드 번호가 없으면(개발·테스트) 확인하지 않는다
  bool get enabled => current.isNotEmpty;

  void start() {
    if (!enabled) return;
    _timer = Timer.periodic(const Duration(minutes: 30), (_) => check());
    _life = AppLifecycleListener(onResume: check);
    check();
  }

  Future<void> check() async {
    if (!enabled || available) return;
    try {
      // 캐시된 예전 파일을 받지 않게 매번 다른 주소로 묻는다
      final url = Uri.base.resolve('build.json').replace(
          queryParameters: {'t': '${DateTime.now().millisecondsSinceEpoch}'});
      final res = await _client.get(url);
      if (res.statusCode != 200) return;
      final build = (jsonDecode(res.body) as Map)['build'];
      if (build is String && build.isNotEmpty && build != current) {
        latest = build;
        available = true;
        notifyListeners();
      }
    } catch (_) {
      // 오프라인 등: 다음에 다시 확인한다
    }
  }

  void reload() => reloadToVersion(latest ?? current);

  @override
  void dispose() {
    _timer?.cancel();
    _life?.dispose();
    super.dispose();
  }
}
