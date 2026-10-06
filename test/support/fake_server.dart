import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_amatda/data/sync_records.dart';

/// 테스트용 서버: bot/src/sync.js·auth.js와 같은 규칙으로 동작한다 (사용자 한 명)
class FakeServer {
  int version = 0;
  bool offline = false;
  String? loginCode = 'login-ok';
  final tables = {for (final t in syncTables) t: <String, Map<String, dynamic>>{}};
  final user = {
    'id': 'u_1',
    'email': 'moondaniel082@gmail.com',
    'name': '문',
    'picture': '',
    'owner': true,
  };
  int syncCalls = 0;

  late final client = MockClient((req) async {
    if (offline) throw http.ClientException('offline');
    final path = req.url.path;
    final body = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body);
    http.Response reply(int status, Object b) => http.Response.bytes(
        utf8.encode(jsonEncode(b)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
    http.Response ok(Object b) => reply(200, b);
    if (path == '/auth/exchange') {
      if (body['code'] != loginCode) {
        return reply(401, {'error': '로그인 코드가 만료됐어요'});
      }
      loginCode = null;
      return ok({'token': 'tok', 'user': user});
    }
    if (req.headers['Authorization'] != 'Bearer tok') {
      return reply(401, {'error': '로그인이 필요해요'});
    }
    if (path == '/auth/me') return ok({'user': user});
    if (path == '/auth/logout') return ok({'ok': true});
    if (path == '/api/telegram') return ok({'linked': false});
    if (path == '/api/telegram/code') return ok({'code': 'c'});
    if (path == '/api/sync') return ok(_sync(body as Map<String, dynamic>));
    return reply(404, {'error': '없는 주소'});
  });

  Map<String, Object> _sync(Map<String, dynamic> body) {
    syncCalls++;
    final since = body['since'] as int;
    final changes = body['changes'] as Map<String, dynamic>;
    for (final t in syncTables) {
      for (final r in (changes[t] as List? ?? const [])) {
        tables[t]![r['id'] as String] = {
          ...(r as Map<String, dynamic>),
          'deleted': r['deleted'] == true,
          'version': ++version,
        };
      }
    }
    return {
      'version': version,
      'more': false,
      'changes': {
        for (final t in syncTables)
          t: [
            for (final r in tables[t]!.values)
              if ((r['version'] as int) > since) r,
          ],
      },
    };
  }

  /// 살아 있는(삭제되지 않은) 행 id들
  List<String> ids(String table) => [
        for (final r in tables[table]!.values)
          if (r['deleted'] != true) r['id'] as String,
      ];
}
