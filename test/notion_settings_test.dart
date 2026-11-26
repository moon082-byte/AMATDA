import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_amatda/services/api_client.dart';
import 'package:flutter_application_amatda/services/notion_service.dart';
import 'package:flutter_application_amatda/views/notion_settings_page.dart';
import 'package:provider/provider.dart';

const _taskDb = '1111ece31bb580509babd28537b58808';

/// bot/src/notion_routes.js와 같은 규칙의 가짜 서버 (토큰은 돌려주지 않는다, 매핑 확인은 생략)
class _NotionServer {
  bool enabled = false;
  String? token;
  final dbs = <String, Object?>{'task': null, 'memo': null};
  final maps = <String, Object?>{'task': null, 'memo': null};
  final puts = <Map<String, dynamic>>[];
  final backfills = <String>[];

  Map<String, Object?> get view => {
        'enabled': enabled, 'hasToken': token != null,
        'taskDb': dbs['task'], 'taskMap': maps['task'], 'memoDb': dbs['memo'], 'memoMap': maps['memo'],
        'waiting': 0, 'failed': 0,
      };

  late final api = ApiClient(
    baseUrl: 'https://bot.test',
    token: () => 'tok',
    client: MockClient((req) async {
      final body = req.body.isEmpty ? <String, dynamic>{} : jsonDecode(req.body) as Map<String, dynamic>;
      http.Response reply(int status, Object b) => http.Response.bytes(utf8.encode(jsonEncode(b)), status);
      final path = req.url.path;
      if (path == '/api/notion/inspect') {
        if ((body['token'] ?? token) == null) return reply(400, {'error': '노션 통합 토큰을 입력해 주세요'});
        if (!'${body['db']}'.contains(_taskDb)) return reply(400, {'error': '데이터베이스를 찾을 수 없어요'});
        return reply(200, {
          'id': _taskDb, 'name': '할 일 목록',
          'properties': [
            {'name': '작업', 'type': 'title'}, {'name': '마감', 'type': 'date'}, {'name': '메모', 'type': 'rich_text'},
            {'name': '진행', 'type': 'status', 'options': ['시작 전', '진행 중', '완료']},
          ],
        });
      }
      if (path == '/api/notion/backfill') {
        backfills.add(body['target'] as String);
        return reply(200, {'count': 3});
      }
      if (req.method == 'PUT') {
        puts.add(body);
        token = body['token'] as String? ?? token;
        enabled = body['enabled'] as bool;
        for (final k in ['task', 'memo']) {
          if (body.containsKey('${k}Db')) {
            dbs[k] = body['${k}Db'] == '' ? null : body['${k}Db'];
            maps[k] = body['${k}Map'];
          }
        }
      }
      if (req.method == 'DELETE') {
        enabled = false;
        token = null;
        dbs.updateAll((_, _) => null);
      }
      return reply(200, view);
    }),
  );
}

/// 긴 화면이라 아직 그려지지 않은 버튼은 스크롤해서 찾는다 (아래로, 없으면 위로)
Future<void> _reveal(WidgetTester tester, Finder f) async {
  final list = find.byType(Scrollable).first;
  for (final dy in [300.0, -300.0]) {
    if (f.evaluate().isNotEmpty) break;
    try {
      await tester.scrollUntilVisible(f, dy, scrollable: list, maxScrolls: 15);
    } on StateError {
      // 이쪽 방향에 없으면 반대쪽으로
    }
  }
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await _reveal(tester, f);
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

/// 드롭다운(라벨로 찾음)을 열고 [item]을 고른다
Future<void> _pick(WidgetTester tester, String label, String item) async {
  await _tap(tester, find.widgetWithText(DropdownButtonFormField<String?>, label));
  await tester.tap(find.text(item).last);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('노션 연동: 토큰 → 할일 DB 링크 → 속성 불러오기 → 매핑 → 저장 → 기존 할 일 보내기 → 해제', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 1400 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final server = _NotionServer();
    final service = NotionService(api: server.api);
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: service,
      child: const MaterialApp(home: NotionSettingsPage()),
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('1_Inbox'), findsNothing, reason: '특정 데이터베이스 이름은 쓰지 않는다');
    expect(find.text('연동 방법'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'ntn_abcdefghijklmnopqrstuvwxyz');
    await tester.enterText(fields.at(1), 'https://www.notion.so/할일-$_taskDb?v=1');
    await tester.pump();
    // 속성을 불러오지 않고 저장하면 안내한다
    await _tap(tester, find.text('저장'));
    expect(find.text('할 일 데이터베이스의 [속성 불러오기]를 먼저 눌러 주세요'), findsOneWidget);

    await _tap(tester, find.text('속성 불러오기').first);
    expect(find.text('"할 일 목록" 연결됨'), findsOneWidget);
    expect(find.text('작업'), findsOneWidget, reason: '제목 속성은 하나라 바로 고른다');
    await _pick(tester, '완료', '진행');
    await _pick(tester, '완료일 때 값', '완료');
    await _pick(tester, '할 일일 때 값', '시작 전');
    await _pick(tester, '날짜 (마감)', '마감');
    await _tap(tester, find.byType(Switch));
    await _tap(tester, find.text('저장'));
    expect(find.textContaining('저장했어요'), findsOneWidget);
    final put = server.puts.single;
    expect(put['token'], 'ntn_abcdefghijklmnopqrstuvwxyz');
    expect(put['taskDb'], _taskDb);
    expect(put['taskMap'], {
      'title': '작업', 'date': '마감', 'done': {'prop': '진행', 'doneValue': '완료', 'todoValue': '시작 전'},
    });
    expect(put.containsKey('memoDb'), isFalse, reason: '손대지 않은 메모 DB는 보내지 않는다');
    expect([service.enabled, service.taskOn, service.memoOn], [true, true, false]);

    await _tap(tester, find.text('기존 할 일 노션에 보내기'));
    await _tap(tester, find.widgetWithText(FilledButton, '보내기'));
    expect(server.backfills, ['tasks']);
    expect(find.text('할 일 3개를 노션에 보내고 있어요'), findsOneWidget);

    await _tap(tester, find.text('연동 해제'));
    await _tap(tester, find.widgetWithText(FilledButton, '해제'));
    expect([service.enabled, service.hasToken, service.taskDb], [false, false, null]);
  });

  test('로그인하지 않았으면 노션 연동을 쓸 수 없다', () {
    expect(NotionService().available, isFalse);
  });
}
