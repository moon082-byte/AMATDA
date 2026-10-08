import 'package:flutter/foundation.dart';
import '../config/bot_config.dart';
import 'launch_url_cleanup.dart';

/// 텔레그램 알림의 [앱에서 보기] 링크로 열 항목.
/// 주소 형식: `<앱 주소>?open=task:<id>` (room:, routine:도 같은 형식)
typedef LaunchTarget = ({String kind, String id});

const _param = 'open';
const _kinds = {'task', 'room', 'routine'};

LaunchTarget? _pending;

/// [kind] 항목 [id]를 바로 여는 앱 주소
String appLinkFor(String kind, String id) =>
    '$kAppUrl?$_param=$kind:${Uri.encodeQueryComponent(id)}';

/// 주소에서 열 항목을 읽는다. 형식이 맞지 않으면 null.
LaunchTarget? parseLaunchTarget(Uri uri) =>
    _parseValue(uri.queryParameters[_param]);

/// `task:<id>` → 열 항목. 형식이 맞지 않으면 null.
LaunchTarget? _parseValue(String? value) {
  final sep = value?.indexOf(':') ?? -1;
  if (value == null || sep <= 0) return null;
  final kind = value.substring(0, sep);
  final id = value.substring(sep + 1);
  if (!_kinds.contains(kind) || id.isEmpty) return null;
  return (kind: kind, id: id);
}

/// 구글 로그인에서 돌아왔을 때 주소에 붙는 값 (`?login=<일회용 코드>` 또는 `?login_error=<이유>`)
typedef LoginResult = ({String? code, String? error});

/// 앱 시작 시 한 번 호출: 열 항목과 로그인 결과를 읽어 두고, 새로고침해도
/// 다시 처리되지 않게 주소창에서 해당 부분(?open=, ?login=)을 지운다.
LoginResult captureStartupParams() {
  final uri = Uri.base;
  _pending = parseLaunchTarget(uri);
  final params = uri.queryParameters;
  final login = (code: params['login'], error: params['login_error']);
  final rest = Map.of(params)
    ..remove(_param)
    ..remove('login')
    ..remove('login_error');
  if (rest.length != params.length) {
    final query = rest.isEmpty ? '' : '?${Uri(queryParameters: rest).query}';
    final fragment = uri.hasFragment ? '#${uri.fragment}' : '';
    replaceBrowserUrl('${uri.path}$query$fragment');
  }
  return login;
}

/// 아직 열지 않은 항목 (`task:<id>` 형식, 없으면 null). 로그인하러 떠나기 전에 저장해 둔다.
String? pendingLaunchValue() {
  final t = _pending;
  return t == null ? null : '${t.kind}:${t.id}';
}

/// 로그인하고 돌아왔을 때 저장해 둔 항목을 되살린다
void restoreLaunchTarget(String? value) => _pending ??= _parseValue(value);

/// 기억해 둔 항목을 꺼낸다 (한 번만)
LaunchTarget? takeLaunchTarget() {
  final target = _pending;
  _pending = null;
  return target;
}

/// 테스트에서 [앱에서 보기]로 들어온 상황을 흉내 낸다
@visibleForTesting
void debugSetLaunchTarget(LaunchTarget? target) => _pending = target;
