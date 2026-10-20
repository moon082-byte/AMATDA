import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_amatda/providers/notification_provider.dart';
import 'package:flutter_application_amatda/services/api_client.dart';
import 'package:flutter_application_amatda/views/home_shell.dart';
import 'package:flutter_application_amatda/views/project_list_view.dart';
import 'package:flutter_application_amatda/widgets/session_scope.dart';

/// 가짜 봇 서버: 프로젝트방 하나 (나 = me, 팀장 = boss)
class _Server {
  final calls = <String>[];
  final bool leader;
  bool done = false;
  final projects = <Map<String, Object?>>[];

  _Server({this.leader = false}) {
    projects.add({'id': 'p1', 'name': '디자인', 'dueAt': null, 'tasks': [_task()]});
  }

  Map<String, Object?> _task() => {
        'id': 't1', 'projectId': 'p1', 'title': '시안 만들기', 'assigneeId': 'me',
        'dueAt': DateTime.now().add(const Duration(days: 3)).millisecondsSinceEpoch,
        'doneAt': done ? 1 : null,
      };

  Map<String, Object?> get detail => {
        'room': {'id': 'r1', 'name': '신제품', 'goal': '11월 출시', 'telegramUrl': '', 'leaderId': 'boss'},
        'me': {'userId': 'me', 'role': leader ? 'leader' : 'member', 'status': 'active'},
        'members': [
          {'userId': 'boss', 'role': 'leader', 'status': 'active', 'nickname': '팀장', 'tag': '1111', 'handle': '팀장#1111'},
          {'userId': 'me', 'role': 'member', 'status': 'active', 'nickname': '나', 'tag': '2222', 'handle': '나#2222'},
        ],
        'projects': [for (final p in projects) {...p, if (p['id'] == 'p1') 'tasks': [_task()]}],
      };

  late final api = ApiClient(
    baseUrl: 'https://bot.test',
    token: () => 'tok',
    client: MockClient((req) async {
      final key = '${req.method} ${req.url.path}';
      calls.add('$key ${req.url.query} ${req.body}'.trim());
      Object body = {'ok': true};
      if (key == 'GET /api/profile') body = {'nickname': '나', 'tag': '2222', 'bio': '', 'avatar': null};
      if (key == 'POST /api/telegram/code') body = {'code': 'c1'};
      if (key == 'GET /api/telegram') body = {'linked': false, 'nag': true};
      if (key == 'GET /api/project-rooms') {
        final page = int.parse(req.url.queryParameters['page'] ?? '1');
        body = {
          'page': page, 'pageSize': 10, 'total': 12,
          'rooms': [for (var i = 0; i < (page == 1 ? 10 : 2); i++) {'id': 'r$i', 'name': '방 ${(page - 1) * 10 + i}', 'role': 'member', 'members': 2, 'total': 4, 'done': 1, 'myOpen': 1}],
          'invites': [{'roomId': 'r1', 'roomName': '신제품', 'invitedBy': '팀장#1111'}],
        };
      }
      if (key.startsWith('GET /api/project-rooms/') || key.endsWith('/accept')) body = detail;
      if (key == 'POST /api/project-tasks/t1/complete') {
        done = true;
        body = detail;
      }
      if (key == 'POST /api/project-rooms/r1/projects') {
        projects.add({'id': 'p2', 'name': (jsonDecode(req.body) as Map)['name'], 'dueAt': null, 'tasks': []});
        body = detail;
      }
      return http.Response(jsonEncode(body), 200, headers: {'content-type': 'application/json; charset=utf-8'});
    }),
  );
}

Future<void> _boot(WidgetTester tester, _Server server) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => NotificationProvider(),
    child: MaterialApp(
      builder: (context, child) => SessionScope(api: server.api, child: child!),
      home: const HomeShell(),
    ),
  ));
  await tester.pumpAndSettle();
  await tester.tap(find.text('프로젝트').last);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('목록은 10개씩, 다음 페이지로 넘기고, 받은 초대를 수락하면 그 방이 열린다', (tester) async {
    final server = _Server();
    await _boot(tester, server);
    expect(find.text('방 0'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('1 / 2'), 300,
        scrollable: find.descendant(
            of: find.byType(ProjectListView), matching: find.byType(Scrollable)).first);
    expect(find.text('1 / 2'), findsOneWidget);
    await _tap(tester, find.byTooltip('다음 페이지'));
    expect(find.text('방 10'), findsOneWidget);
    expect(server.calls.where((c) => c.contains('page=2')), isNotEmpty);

    await tester.scrollUntilVisible(find.text('수락'), -300,
        scrollable: find.descendant(
            of: find.byType(ProjectListView), matching: find.byType(Scrollable)).first);
    await _tap(tester, find.text('수락'));
    expect(server.calls, contains(startsWith('POST /api/project-rooms/r1/accept')));
    expect(find.textContaining('11월 출시'), findsOneWidget);
  });

  testWidgets('팀원: 내 업무 [완료] → "완료 보고 드리겠습니까?" → 완료 보고', (tester) async {
    final server = _Server();
    await _boot(tester, server);
    await _tap(tester, find.text('방 0'));
    expect(find.textContaining('1개', findRichText: true), findsOneWidget); // 할 일 1개가 남아있어요
    expect(find.text('D-3'), findsOneWidget);
    expect(find.byTooltip('방 관리'), findsNothing, reason: '팀원은 방을 고칠 수 없다');

    await _tap(tester, find.widgetWithText(FilledButton, '완료'));
    expect(find.text('완료 보고 드리겠습니까?'), findsOneWidget);
    await _tap(tester, find.text('완료 보고'));
    expect(server.calls, contains(startsWith('POST /api/project-tasks/t1/complete')));
    expect(find.text('내 할 일을 모두 끝냈어요'), findsOneWidget);
  });

  testWidgets('팀장: [프로젝트 추가] 시트로 새 프로젝트를 만든다', (tester) async {
    final server = _Server(leader: true);
    await _boot(tester, server);
    await _tap(tester, find.text('방 0'));
    await _tap(tester, find.text('프로젝트 추가'));
    await tester.enterText(find.byType(TextField).last, '홍보');
    await _tap(tester, find.text('저장하기'));
    expect(server.calls, contains(contains('POST /api/project-rooms/r1/projects  {"name":"홍보"')));
    expect(find.text('홍보'), findsOneWidget);
  });

  testWidgets('[프로세스] 탭은 준비 중 안내를 보여준다', (tester) async {
    await _boot(tester, _Server());
    await _tap(tester, find.text('프로세스').last);
    expect(find.text('준비 중이에요'), findsOneWidget);
  });
}
