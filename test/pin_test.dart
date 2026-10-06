import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_amatda/data/local_store.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/services/api_client.dart';
import 'package:flutter_application_amatda/services/auth_service.dart';
import 'package:flutter_application_amatda/services/pin_service.dart';
import 'support/fake_server.dart';

const _session = '{"token":"tok","user":{"id":"u_1","email":"moondaniel082@gmail.com",'
    '"name":"문","picture":"","owner":false}}';

Future<PinService> _pin(FakeServer server) async {
  final store = (await LocalStore.open()).forUser('u_1');
  final api = ApiClient(baseUrl: 'https://api.test', token: () => 'tok', client: server.client);
  return PinService(api: api, store: store);
}

/// 키패드로 숫자를 누른다
Future<void> _type(WidgetTester tester, String digits) async {
  for (final d in digits.split('')) {
    await tester.tap(find.widgetWithText(TextButton, d));
    await tester.pump();
  }
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pump();
}

Future<FakeServer> _openApp(WidgetTester tester, FakeServer server) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({'session_v1': _session});
  final (store, auth) = await tester.runAsync(() async {
    final store = await LocalStore.open();
    final auth = AuthService(store: store, client: server.client, apiUrl: 'https://api.test');
    await auth.init();
    return (store, auth);
  }).then((v) => v!);
  await tester.pumpWidget(MyApp(store: store, auth: auth));
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
  await tester.pumpAndSettle();
  return server;
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('PIN을 켜면 앱을 다시 열 때마다 잠기고, 맞게 입력하면 풀린다', () async {
    final server = FakeServer();
    final first = await _pin(server);
    await first.load();
    expect(first.status, PinStatus.unlocked);
    expect(await first.setPin('1234'), isNull);
    expect(first.enabled, isTrue);

    final reopened = await _pin(server);
    await reopened.load();
    expect(reopened.status, PinStatus.locked);
    expect(await reopened.verify('0000'), isFalse);
    expect(reopened.remaining, 4);
    expect(await reopened.verify('1234'), isTrue);
    expect(reopened.status, PinStatus.unlocked);
  });

  test('5번 틀리면 잠기고, 잠긴 동안은 맞아도 안 된다', () async {
    final server = FakeServer()..pin = '1234';
    final pin = await _pin(server);
    await pin.load();
    for (var i = 0; i < 5; i++) {
      await pin.verify('9999');
    }
    final left = pin.lockedUntil!.difference(DateTime.now());
    expect(left.inSeconds, inInclusiveRange(55, 60));
    expect(await pin.verify('1234'), isFalse);
    expect(pin.status, PinStatus.locked);
  });

  test('오프라인이면 PIN을 켠 계정은 막고, 안 켠 계정은 그대로 연다', () async {
    final server = FakeServer()..pin = '1234';
    await (await _pin(server)).load(); // 켜져 있다는 것을 기억
    server.offline = true;
    final pin = await _pin(server);
    await pin.load();
    expect(pin.status, PinStatus.offline);
    expect(pin.message, '인터넷 연결 후 입력해 주세요');

    SharedPreferences.setMockInitialValues({});
    final noPin = await _pin(server);
    await noPin.load();
    expect(noPin.status, PinStatus.unlocked);
  });

  test('다른 기기에서 PIN을 켜면 이 기기도 다음 요청 때 다시 잠근다', () async {
    final server = FakeServer();
    final pin = await _pin(server);
    await pin.load();
    final api = ApiClient(baseUrl: 'https://api.test', token: () => 'tok', client: server.client)
      ..onPinRequired = pin.requireAgain;
    server
      ..pin = '1234' // 다른 기기에서 켬
      ..pinVerified = false;
    await expectLater(api.post('/api/sync', {'since': 0, 'changes': {}}),
        throwsA(isA<ApiException>().having((e) => e.isPinRequired, 'PIN 필요', isTrue)));
    expect(pin.status, PinStatus.locked);
  });

  testWidgets('앱을 열면 PIN 화면이 나오고, 틀리면 남은 횟수, 맞으면 앱이 열린다', (tester) async {
    await _openApp(tester, FakeServer()..pin = '1357');
    expect(find.text('PIN을 입력해 주세요'), findsOneWidget);
    expect(find.text('오늘 할일'), findsNothing);

    await _type(tester, '0000');
    expect(find.textContaining('남은 횟수 4번'), findsOneWidget);
    await _type(tester, '1357');
    await tester.pumpAndSettle();
    expect(find.text('오늘 할일'), findsOneWidget);
  });

  testWidgets('PIN을 잊으면 텔레그램 코드로 새 PIN을 정한다', (tester) async {
    final server = await _openApp(tester, FakeServer()..pin = '1357');
    await tester.tap(find.text('PIN을 잊었어요'));
    await tester.pumpAndSettle();
    expect(find.textContaining('PIN 번호 자체는 알려드릴 수 없어요'), findsOneWidget);
    await tester.tap(find.text('텔레그램으로 재설정 코드 받기'));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
    await tester.pumpAndSettle();
    expect(find.text('재설정 코드'), findsOneWidget);

    await _type(tester, server.resetCode!);
    await _type(tester, '2468');
    await _type(tester, '2468');
    await tester.pumpAndSettle();
    expect(server.pin, '2468');
    expect(find.text('오늘 할일'), findsOneWidget);
  });

  testWidgets('설정에서 PIN을 켠다 (두 번 입력)', (tester) async {
    final server = await _openApp(tester, FakeServer());
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(Switch).first);
    await tester.pumpAndSettle();
    expect(find.text('새 PIN 4자리'), findsOneWidget);

    await _type(tester, '4321');
    await _type(tester, '1111');
    expect(find.text('PIN이 서로 달라요. 다시 입력해 주세요'), findsOneWidget);
    await _type(tester, '4321');
    await _type(tester, '4321');
    await tester.pumpAndSettle();
    expect(server.pin, '4321');
    expect(find.textContaining('PIN을 켰어요'), findsOneWidget);
  });
}
