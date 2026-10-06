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
LaunchTarget? parseLaunchTarget(Uri uri) {
  final value = uri.queryParameters[_param];
  final sep = value?.indexOf(':') ?? -1;
  if (value == null || sep <= 0) return null;
  final kind = value.substring(0, sep);
  final id = value.substring(sep + 1);
  if (!_kinds.contains(kind) || id.isEmpty) return null;
  return (kind: kind, id: id);
}

/// 앱 시작 시 한 번 호출: 열 항목을 기억하고, 새로고침해도 다시 열리지 않게
/// 주소창에서 ?open= 부분을 지운다.
void captureLaunchTarget() {
  final uri = Uri.base;
  _pending = parseLaunchTarget(uri);
  if (_pending == null) return;
  final rest = Map.of(uri.queryParameters)..remove(_param);
  final query = rest.isEmpty ? '' : '?${Uri(queryParameters: rest).query}';
  final fragment = uri.hasFragment ? '#${uri.fragment}' : '';
  replaceBrowserUrl('${uri.path}$query$fragment');
}

/// 기억해 둔 항목을 꺼낸다 (한 번만)
LaunchTarget? takeLaunchTarget() {
  final target = _pending;
  _pending = null;
  return target;
}

/// 테스트에서 [앱에서 보기]로 들어온 상황을 흉내 낸다
@visibleForTesting
void debugSetLaunchTarget(LaunchTarget? target) => _pending = target;
