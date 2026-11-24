import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_amatda/services/api_client.dart';
import 'package:flutter_application_amatda/services/notion_service.dart';
import 'package:flutter_application_amatda/views/notion_settings_page.dart';
import 'package:provider/provider.dart';

/// bot/src/notion_routes.js와 같은 규칙의 가짜 서버 (토큰은 돌려주지 않는다)
class _NotionServer {
  bool enabled = false;
  String? token;
  String? memoDb;
  final requests = <String>[];

  Map<String, Object?> get view => {'enabled': enabled, 'hasToken': token != null, 'memoDb': memoDb};

  late final api = ApiClient(
    baseUrl: 'https://bot.test',
    token: () => 'tok',
    client: MockClient((req) async {
      final body = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>;
      requests.add('${req.method} ${req.url.path} ${req.body}');
      http.Response reply(int status, Object b) =>
          http.Response.bytes(utf8.encode(jsonEncode(b)), status);
      String? id(Object? v) => v == null ? null : RegExp(r'[0-9a-f]{32}').allMatches('$v').last.group(0);
      final t = body['token'] as String? ?? token;
      final db = id(body['memoDb']) ?? memoDb;
      if (req.url.path == '/api/notion/check' || (req.method == 'PUT' && body['enabled'] == true)) {
        if (t == null) return reply(400, {'error': '노션 통합 토큰을 입력해 주세요'});
        if (db == null) return reply(400, {'error': '메모용 DB ID(또는 DB 주소)를 입력해 주세요'});
        if (req.url.path == '/api/notion/check') return reply(200, {'ok': true, 'message': '노션 메모 DB에 연결할 수 있어요'});
      }
      if (req.method == 'PUT') {
        enabled = body['enabled'] as bool;
        token = t;
        memoDb = db;
      }
      if (req.method == 'DELETE') {
        enabled = false;
        token = memoDb = null;
      }
      return reply(200, view);
    }),
  );
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('노션 연동: 토큰·DB 주소로 연결 확인 → 켜서 저장 → 토큰은 다시 받지 않고, 해제하면 지운다', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final server = _NotionServer();
    final service = NotionService(api: server.api);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: service,
      child: const MaterialApp(home: NotionSettingsPage()),
    ));
    await tester.pumpAndSettle();

    // 토큰 없이 켜서 저장하면 서버가 알려준 이유를 보여준다
    await _tap(tester, find.byType(Switch));
    await _tap(tester, find.text('저장'));
    expect(find.text('노션 통합 토큰을 입력해 주세요'), findsOneWidget);
    expect(service.enabled, isFalse);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'ntn_abcdefghijklmnopqrstuvwxyz');
    await tester.enterText(fields.at(1), 'https://www.notion.so/1_Inbox-3955ece31bb580509babd28537b58808?v=1');
    await _tap(tester, find.text('연결 확인'));
    expect(find.text('노션 메모 DB에 연결할 수 있어요'), findsOneWidget);
    await _tap(tester, find.text('저장'));
    expect(find.textContaining('노션 연동을 켰어요'), findsOneWidget);
    expect([service.enabled, service.hasToken, service.memoDb],
        [true, true, '3955ece31bb580509babd28537b58808']);
    expect(server.token, 'ntn_abcdefghijklmnopqrstuvwxyz');
    expect(find.text('저장된 토큰이 있어요 (바꿀 때만 입력)'), findsOneWidget, reason: '토큰 칸은 비우고 안내만');

    // 끄기: 토큰은 다시 보내지 않고 저장된 것을 그대로 둔다
    await _tap(tester, find.byType(Switch));
    server.requests.clear();
    await _tap(tester, find.text('저장'));
    expect(server.requests.single, contains('"enabled":false'));
    expect(server.requests.single, isNot(contains('token')));
    expect([service.enabled, service.hasToken], [false, true]);

    await _tap(tester, find.text('연동 해제'));
    await _tap(tester, find.widgetWithText(FilledButton, '해제'));
    expect([service.enabled, service.hasToken, server.token], [false, false, null]);
    expect(find.text('연동 해제'), findsNothing);
  });

  test('로그인하지 않았으면 노션 연동을 쓸 수 없다', () {
    expect(NotionService().available, isFalse);
  });
}
