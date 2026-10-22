import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_amatda/models/project_link.dart';
import 'package:flutter_application_amatda/models/task_item.dart';
import 'package:flutter_application_amatda/providers/notification_provider.dart';
import 'package:flutter_application_amatda/providers/room_provider.dart';
import 'package:flutter_application_amatda/services/api_client.dart';
import 'package:flutter_application_amatda/views/home_shell.dart';
import 'package:flutter_application_amatda/views/project_list_view.dart';
import 'package:flutter_application_amatda/widgets/session_scope.dart';

/// 가짜 봇 서버: 프로젝트방 하나 (나 = me, 팀장 = boss)
class _Server {
  final calls = <String>[];
  final bool leader;
  final int dueInDays;
  bool done = false;
  final projects = <Map<String, Object?>>[];

  _Server({this.leader = false, this.dueInDays = 3}) {
    projects.add({'id': 'p1', 'name': '디자인', 'dueAt': null, 'tasks': [_task()]});
  }

  Map<String, Object?> _task() => {
        'id': 't1', 'projectId': 'p1', 'title': '시안 만들기', 'assigneeId': 'me',
        'dueAt': DateTime.now().add(Duration(days: dueInDays)).millisecondsSinceEpoch,
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
          'rooms': [for (var i = 0; i < (page == 1 ? 10 : 2); i++) {'id': 'r$i', 'name': '방 ${(page - 1) * 10 + i}', 'role': leader ? 'leader' : 'member', 'members': 2, 'total': 4, 'done': 1, 'myOpen': 1}],
          'invites': [{'roomId': 'r1', 'roomName': '신제품', 'invitedBy': '팀장#1111'}],
        };
      }
      if (key.startsWith('GET /api/project-rooms/') || key.endsWith('/accept')) body = detail;
      if (key == 'POST /api/project-tasks/t1/complete') {
        done = true;
        body = detail;
      }
      if (key.startsWith('DELETE /api/project') || key.endsWith('/invites')) body = detail;
      if (key == 'GET /api/users/lookup') body = {'userId': 'u9', 'handle': '새팀원#3333'};
      if (key == 'DELETE /api/project-rooms/r0') body = {'ok': true};
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

  testWidgets('팀원: 내 업무 [🔔]은 개인 할일에 들어온 그 업무의 리마인더를 바꾼다', (tester) async {
    await _boot(tester, _Server());
    final rooms = tester.element(find.byType(HomeShell)).read<RoomProvider>();
    await _tap(tester, find.text('방 0'));
    await _tap(tester, find.byTooltip('리마인더 설정'));
    expect(find.textContaining('개인 할일로 가져오는 중'), findsOneWidget, reason: '아직 동기화 전');

    rooms.addTask(TaskItem(
      id: 'pt_t1', title: '시안 만들기', createdAt: DateTime.now(),
      dueDate: DateTime.now().add(const Duration(days: 3)),
      project: const ProjectLink(roomId: 'r1', roomName: '신제품', projectName: '디자인', taskId: 't1'),
    ));
    await tester.pumpAndSettle();
    await _tap(tester, find.byTooltip('리마인더 설정'));
    await _tap(tester, find.text('리마인더 추가'));
    await _tap(tester, find.text('확인'));
    expect(rooms.taskById('pt_t1')!.remindAt, hasLength(1));
    expect(find.byTooltip('리마인더 1개'), findsOneWidget);
  });

  testWidgets('방 화면: 오늘 마감 업무는 "오늘의 일정"에, [팀원] 탭은 팀원별 업무를 보여준다', (tester) async {
    await _boot(tester, _Server(dueInDays: 0));
    await _tap(tester, find.text('방 0'));
    expect(find.text('오늘의 일정'), findsOneWidget);
    expect(find.text('📁 디자인'), findsOneWidget, reason: '오늘의 일정에는 프로젝트 이름도 붙는다');

    await _tap(tester, find.text('팀원 2'));
    expect(find.text('팀장#1111'), findsOneWidget);
    expect(find.text('진행 중 1'), findsOneWidget); // 나#2222 (기본 펼침)
    expect(find.text('완료 0'), findsOneWidget);
    expect(find.text('배정된 업무가 없어요'), findsOneWidget); // 팀장
  });

  testWidgets('팀장: 프로젝트에 리마인더를 걸면 함께 저장된다', (tester) async {
    final server = _Server(leader: true);
    await _boot(tester, server);
    await _tap(tester, find.text('방 0'));
    await _tap(tester, find.text('프로젝트 추가'));
    await tester.enterText(find.byType(TextField).last, '홍보');
    await _tap(tester, find.byTooltip('리마인더 설정').last);
    await _tap(tester, find.text('리마인더 추가'));
    await _tap(tester, find.text('확인'));
    await _tap(tester, find.text('저장하기'));
    final body = server.calls.firstWhere((c) => c.startsWith('POST /api/project-rooms/r1/projects'));
    expect(RegExp(r'"remindAt":\[\d+\]').hasMatch(body), isTrue, reason: body);
  });

  testWidgets('팀장: 프로젝트 카드를 밀어 삭제, 업무 ✕ 삭제는 확인 창을 거친다 ([팀원] 버튼은 없다)', (tester) async {
    final server = _Server(leader: true);
    await _boot(tester, server);
    await _tap(tester, find.text('방 0'));
    expect(find.byTooltip('팀원'), findsNothing);

    await _tap(tester, find.byTooltip('업무 삭제'));
    expect(find.text('삭제할까요?'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, '삭제'));
    expect(server.calls, contains(startsWith('DELETE /api/project-tasks/t1')));

    await tester.ensureVisible(find.text('디자인').last);
    await tester.drag(find.text('디자인').last, const Offset(-300, 0));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('삭제').last);
    await _tap(tester, find.widgetWithText(FilledButton, '삭제'));
    expect(server.calls, contains(startsWith('DELETE /api/projects/p1')));
  });

  testWidgets('팀원: 밀어도 수정·삭제가 없고 업무 ✕도 없다', (tester) async {
    await _boot(tester, _Server());
    await _tap(tester, find.text('방 0'));
    expect(find.byTooltip('업무 삭제'), findsNothing);
    await tester.ensureVisible(find.text('디자인').last);
    await tester.drag(find.text('디자인').last, const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('수정'), findsNothing);
  });

  testWidgets('팀장: [팀원] 탭에서 닉네임#태그로 초대하고, 카드를 밀어 내보낸다', (tester) async {
    final server = _Server(leader: true);
    await _boot(tester, server);
    await _tap(tester, find.text('방 0'));
    await _tap(tester, find.text('팀원 2'));
    await tester.enterText(find.byType(TextField).first, '새팀원#3333');
    await _tap(tester, find.byTooltip('팀원 찾기'));
    expect(server.calls, contains(contains('POST /api/project-rooms/r1/invites  {"userId":"u9"}')));

    await tester.drag(find.text('나#2222'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('내보내기').first);
    expect(find.text('나#2222님을 내보낼까요?'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, '내보내기'));
    expect(server.calls, contains(startsWith('DELETE /api/project-rooms/r1/members/me')));
  });

  testWidgets('팀원인 방은 목록에서 밀어도 [삭제]가 없다', (tester) async {
    final server = _Server();
    await _boot(tester, server);
    await tester.drag(find.text('방 0'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    expect(find.text('삭제'), findsNothing, reason: '목록의 방은 팀원(role: member)이라 밀리지 않는다');
  });

  testWidgets('팀장인 방: 목록에서 밀어 [삭제] → 확인 창 → 삭제', (tester) async {
    final lead = _Server(leader: true);
    await _boot(tester, lead);
    await tester.drag(find.text('방 0'), const Offset(-300, 0));
    await tester.pumpAndSettle();
    await _tap(tester, find.text('삭제').last);
    expect(find.text('삭제할까요?'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, '삭제'));
    expect(lead.calls, contains(startsWith('DELETE /api/project-rooms/r0')));
  });
}
