import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:flutter_application_amatda/services/api_client.dart';
import 'package:flutter_application_amatda/services/push_service.dart';
import 'package:flutter_application_amatda/services/telegram_link.dart';
import 'package:flutter_application_amatda/widgets/horizontal_scroller.dart';
import 'package:flutter_application_amatda/widgets/push_notification_tile.dart';

const _sub = '{"endpoint":"https://push.test/a","keys":{"p256dh":"P","auth":"A"}}';

/// 가짜 봇 서버: 받은 요청을 기록한다
class _Server {
  final calls = <String>[];
  late final api = ApiClient(
    baseUrl: 'https://bot.test',
    token: () => 'tok',
    client: MockClient((req) async {
      calls.add('${req.method} ${req.url.path} ${req.body}');
      final body = switch (req.url.path) {
        '/api/push/key' => {'key': 'SERVERKEY'},
        '/api/reminders' => {'ok': true, 'linked': false},
        _ => {'ok': true},
      };
      return http.Response(jsonEncode(body), 200,
          headers: {'content-type': 'application/json; charset=utf-8'});
    }),
  );
}

/// 가짜 브라우저 푸시
PushBridge _bridge({
  bool supported = true,
  bool homeScreen = false,
  String permission = 'default',
  String current = '',
  String subscribeResult = _sub,
  List<String>? log,
}) =>
    PushBridge(
      supported: () => supported,
      needsHomeScreen: () => homeScreen,
      permission: () => permission,
      subscription: () async => current,
      subscribe: (key) async {
        log?.add('subscribe $key');
        return subscribeResult;
      },
      unsubscribe: () async => 'https://push.test/a',
    );

Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  test('알림 허용: 서버 키로 구독해 서버에 저장하고, 끄면 이 기기 구독만 지운다', () async {
    final server = _Server();
    final log = <String>[];
    final push = PushService(api: server.api, bridge: _bridge(log: log));
    await _settle();
    expect(push.state, PushState.off);

    expect(await push.enable(), isNull);
    expect(log, ['subscribe SERVERKEY']);
    expect(push.state, PushState.on);
    expect(server.calls.last, startsWith('POST /api/push/subscribe {"endpoint":"https://push.test/a"'));

    await push.disable();
    expect(push.on, isFalse);
    expect(server.calls.last, 'DELETE /api/push/subscribe {"endpoint":"https://push.test/a"}');
  });

  test('이미 구독한 기기는 켜진 상태로 시작하고 서버에 다시 알린다', () async {
    final server = _Server();
    final push = PushService(
        api: server.api, bridge: _bridge(permission: 'granted', current: _sub));
    await _settle();
    await _settle();
    expect(push.on, isTrue);
    expect(server.calls.where((c) => c.startsWith('POST /api/push/subscribe')), hasLength(1));
  });

  test('거절·아이폰 사파리 탭·로그인 안 함 상태를 구분한다', () async {
    final server = _Server();
    final denied = PushService(
        api: server.api, bridge: _bridge(subscribeResult: 'error:denied'));
    expect(await denied.enable(), contains('차단'));
    expect(
      PushService(api: server.api, bridge: _bridge(supported: false, homeScreen: true)).state,
      PushState.needsHomeScreen,
    );
    expect(PushService(bridge: _bridge()).state, PushState.unavailable);
  });

  test('텔레그램을 연결하지 않아도 알림 일정을 올린다 (푸시용)', () async {
    final server = _Server();
    final link = TelegramLink(api: server.api, botUsername: 'amatda_bot');
    await link.sync([
      {'key': 'k', 'fireAt': 1, 'dueAt': 2, 'text': 't'},
    ]);
    expect(server.calls.single, startsWith('PUT /api/reminders'));
    expect(link.linked, isFalse);
  });

  testWidgets('설정의 시스템 알림: [알림 허용] → 켜짐 → [끄기]', (tester) async {
    final server = _Server();
    final push = PushService(api: server.api, bridge: _bridge());
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ChangeNotifierProvider.value(
            value: push, child: const PushNotificationTile()),
      ),
    ));
    await tester.tap(find.text('알림 허용'));
    await tester.pumpAndSettle();
    expect(find.text('끄기'), findsOneWidget);
    expect(find.textContaining('앱을 닫아 둬도'), findsOneWidget);
  });

  testWidgets('업무방 목록: 마우스로 끌고, ◀ ▶ 버튼으로 넘긴다', (tester) async {
    late ScrollController controller;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: SizedBox(
          height: 100,
          child: HorizontalScroller(
            showArrows: true,
            builder: (c) {
              controller = c;
              return ListView(
                controller: c,
                scrollDirection: Axis.horizontal,
                children: [for (var i = 0; i < 20; i++) const SizedBox(width: 150)],
              );
            },
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byTooltip('이전 업무방'), findsNothing);
    expect(find.byTooltip('다음 업무방'), findsOneWidget);

    await tester.tap(find.byTooltip('다음 업무방'));
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(0));
    expect(find.byTooltip('이전 업무방'), findsOneWidget);

    final before = controller.offset;
    await tester.dragFrom(const Offset(400, 50), const Offset(-200, 0),
        kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
    expect(controller.offset, greaterThan(before), reason: '마우스로 끌어도 넘어간다');
  });
}
