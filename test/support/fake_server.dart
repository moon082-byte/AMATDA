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

  // ---- PIN (bot/src/pin.js와 같은 규칙) ----
  String? pin;
  bool pinVerified = false;
  int pinFailed = 0;
  int pinLockedUntil = 0;
  int pinLevel = 0;
  bool telegram = true;

  // ---- 텔레그램 (bot/src/tg_routes.js) ----
  bool telegramLinked = false;
  bool nag = true;
  final acks = <String>[];

  // ---- 허용 이메일 (bot/src/admin.js) ----
  final allowed = <String>[];
  bool freshLogin = false;
  String? resetCode;
  int now() => DateTime.now().millisecondsSinceEpoch;

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
    if (path.startsWith('/auth/pin')) return _pin(path, req.method, body as Map, reply);
    if (pin != null && !pinVerified) {
      return reply(423, {'error': 'PIN 확인이 필요해요', 'pinRequired': true});
    }
    if (path == '/api/telegram') {
      return ok({'linked': telegramLinked, 'name': '민준', 'nag': nag});
    }
    if (path == '/api/telegram/nag') return ok({'nag': nag = body['enabled'] as bool});
    if (path == '/api/reminders/ack') {
      acks.add(body['ack'] as String);
      return ok({'ok': true});
    }
    if (path == '/api/reminders') return ok({'ok': true});
    if (path == '/api/telegram/code') return ok({'code': 'c'});
    if (path == '/api/sync') return ok(_sync(body as Map<String, dynamic>));
    if (path == '/admin/allowed-emails') {
      if (user['owner'] != true) return reply(403, {'error': '관리자만 쓸 수 있어요'});
      if (req.method == 'POST') allowed.add((body['email'] as String).toLowerCase());
      if (req.method == 'DELETE') allowed.remove(req.url.queryParameters['email']);
      return ok({
        'emails': [
          {'email': user['email'], 'fixed': true},
          for (final e in allowed) {'email': e, 'fixed': false},
        ],
      });
    }
    return reply(404, {'error': '없는 주소'});
  });

  http.Response _pin(String path, String method, Map body,
      http.Response Function(int, Object) reply) {
    http.Response? check(Object? value) {
      if (pinLockedUntil > now()) {
        return reply(423, {'error': '잘못 입력해서 잠겼어요', 'lockedUntil': pinLockedUntil});
      }
      if (value == pin) {
        pinFailed = 0;
        pinLevel = 0;
        return null;
      }
      if (++pinFailed < 5) {
        return reply(400, {'error': 'PIN이 맞지 않아요', 'remaining': 5 - pinFailed});
      }
      pinFailed = 0;
      pinLockedUntil = now() + (pinLevel++ == 0 ? 60000 : 1800000);
      return reply(423, {'error': '잘못 입력해서 잠겼어요', 'lockedUntil': pinLockedUntil});
    }

    http.Response save(Object? value) {
      pin = value as String;
      pinVerified = true;
      return reply(200, {'ok': true, 'enabled': true});
    }

    if (path == '/auth/pin' && method == 'GET') {
      return reply(200, {
        'enabled': pin != null,
        'verified': pinVerified,
        'lockedUntil': pinLockedUntil > now() ? pinLockedUntil : null,
        'remaining': 5 - pinFailed,
        'telegram': telegram,
        'freshLogin': freshLogin,
      });
    }
    if (path == '/auth/pin/verify') {
      final failed = check(body['pin']);
      if (failed != null) return failed;
      pinVerified = true;
      return reply(200, {'ok': true});
    }
    if (path == '/auth/pin' && method == 'PUT') {
      if (pin != null) {
        final failed = check(body['current']);
        if (failed != null) return failed;
      }
      return save(body['pin']);
    }
    if (path == '/auth/pin' && method == 'DELETE') {
      final failed = check(body['current']);
      if (failed != null) return failed;
      pin = null;
      return reply(200, {'ok': true, 'enabled': false});
    }
    if (path == '/auth/pin/reset/send') {
      resetCode = '246810';
      return reply(200, {'ok': true});
    }
    if (path == '/auth/pin/reset') {
      if (!freshLogin && (resetCode == null || body['code'] != resetCode)) {
        return reply(400, {'error': '재설정 코드가 맞지 않아요'});
      }
      resetCode = null;
      pinLockedUntil = 0;
      return save(body['pin']);
    }
    return reply(404, {'error': '없는 주소'});
  }

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
