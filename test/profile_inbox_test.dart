import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:provider/provider.dart';
import 'package:flutter_application_amatda/providers/notification_provider.dart';
import 'package:flutter_application_amatda/services/api_client.dart';
import 'package:flutter_application_amatda/utils/pick_avatar.dart';
import 'package:flutter_application_amatda/views/main_dashboard_view.dart';
import 'package:flutter_application_amatda/widgets/nickname_gate.dart';
import 'package:flutter_application_amatda/widgets/session_scope.dart';

/// 가짜 봇 서버: 프로필 한 개와 알림함
class _Server {
  Map<String, Object?> profile = {'nickname': '', 'tag': '', 'bio': '', 'avatar': null};
  final read = <Object?>[];
  final items = [
    {
      'id': 'n1', 'kind': 'task_edited', 'title': '할 일 수정', 'body': '주간 보고서 작성',
      'target': 'task:task_001', 'createdAt': DateTime.now().millisecondsSinceEpoch, 'read': false,
    },
    {
      'id': 'n2', 'kind': 'reminder', 'title': '🔔 회의', 'body': '', 'target': null,
      'createdAt': DateTime.now().millisecondsSinceEpoch, 'read': true,
    },
  ];

  late final api = ApiClient(
    baseUrl: 'https://bot.test',
    token: () => 'tok',
    client: MockClient((req) async {
      Object body = {'ok': true};
      switch ('${req.method} ${req.url.path}') {
        case 'GET /api/profile':
          body = profile;
        case 'PUT /api/profile':
          profile = {...profile, ...jsonDecode(req.body) as Map<String, dynamic>, 'tag': '4821'};
          body = profile;
        case 'GET /api/notifications':
          body = {'unread': items.where((i) => i['read'] != true).length, 'items': items};
        case 'POST /api/notifications/read':
          read.add(jsonDecode(req.body));
        case 'GET /api/telegram':
          body = {'linked': false, 'nag': true};
        case 'POST /api/telegram/code':
          body = {'code': 'code1'};
      }
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }),
  );
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('첫 로그인: 닉네임 설정 → 헤더에 프로필·안 읽은 알림 → 알림함에서 할 일로 이동', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    final server = _Server();
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => NotificationProvider(),
      child: MaterialApp(
        builder: (context, child) =>
            SessionScope(api: server.api, child: NicknameGate(child: child!)),
        home: const MainDashboardView(),
      ),
    ));
    await tester.pumpAndSettle();

    expect(find.textContaining('닉네임을 정해 주세요'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '문#다니엘');
    await _tap(tester, find.text('시작하기'));
    expect(find.textContaining('# 은 쓸 수 없어요'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '문다니엘');
    await _tap(tester, find.text('시작하기'));

    // 메인 헤더: 좌상단 프로필, 우상단 알림함(안 읽은 1개)
    expect(find.text('문다니엘'), findsOneWidget);
    // 프로필이 있어도 알림함·설정은 오른쪽 끝에 붙는다
    expect(tester.getTopRight(find.byTooltip('설정')).dx, greaterThanOrEqualTo(390 - 20 - 4));
    expect(find.descendant(of: find.byTooltip('알림함'), matching: find.text('1')), findsOneWidget);

    await _tap(tester, find.text('문다니엘'));
    expect(find.textContaining('#4821', findRichText: true), findsOneWidget);
    await _tap(tester, find.byTooltip('뒤로'));

    await _tap(tester, find.byTooltip('알림함'));
    expect(find.text('안 읽은 알림 1개'), findsOneWidget);
    await _tap(tester, find.text('할 일 수정'));
    expect(server.read.single, {'ids': ['n1']});
    expect(find.text('세부 체크리스트'), findsOneWidget, reason: '그 할 일이 펼쳐진 업무방 화면');
  });

  test('프로필 사진은 정사각형 512px 이하·200KB 이하 JPEG로 줄인다', () {
    final big = img.Image(width: 1600, height: 900);
    for (final p in big) {
      p
        ..r = (p.x * 7 + p.y * 3) % 256
        ..g = (p.x * p.y) % 256
        ..b = (p.y * 11) % 256;
    }
    final jpeg = shrinkAvatar(Uint8List.fromList(img.encodePng(big)))!;
    expect(jpeg.length, lessThanOrEqualTo(kMaxAvatarBytes));
    final out = img.decodeJpg(jpeg)!;
    expect([out.width, out.height], [512, 512]);
    expect(shrinkAvatar(Uint8List.fromList([1, 2, 3])), isNull, reason: '사진이 아니면 거부');
  });
}
