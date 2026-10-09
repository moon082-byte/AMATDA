import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_amatda/data/local_store.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/services/api_client.dart';
import 'package:flutter_application_amatda/services/auth_service.dart';
import 'package:flutter_application_amatda/services/telegram_nag.dart';
import 'support/fake_server.dart';

const _session = '{"token":"tok","user":{"id":"u_1","email":"moondaniel082@gmail.com",'
    '"name":"문","picture":"","owner":false}}';

ApiClient _api(FakeServer server) =>
    ApiClient(baseUrl: 'https://api.test', token: () => 'tok', client: server.client);

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pumpAndSettle();
}

void main() {
  test('끈질긴 알림: 서버 설정을 읽고, 바꾸고, 앱에서 연 알림은 끈다', () async {
    final server = FakeServer()..nag = false;
    final nag = TelegramNag(api: _api(server));
    expect(nag.enabled, isTrue, reason: '불러오기 전에는 기본값(켬)');
    await Future<void>.delayed(Duration.zero);
    expect(nag.enabled, isFalse);

    expect(await nag.setEnabled(true), isNull);
    expect(server.nag, isTrue);
    await nag.acknowledge('ab' * 12);
    expect(server.acks, ['ab' * 12]);

    server.offline = true;
    expect(await nag.setEnabled(false), contains('인터넷'));
    expect(nag.enabled, isTrue, reason: '실패하면 원래대로');
  });

  testWidgets('설정에서 끈질긴 알림을 끈다 (텔레그램이 연결돼 있을 때만 보인다)', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'session_v1': _session});
    final server = FakeServer()..telegramLinked = true;
    final (store, auth) = await tester.runAsync(() async {
      final store = await LocalStore.open();
      final auth = AuthService(store: store, client: server.client, apiUrl: 'https://api.test');
      await auth.init();
      return (store, auth);
    }).then((v) => v!);
    await tester.pumpWidget(MyApp(store: store, auth: auth));
    await _settle(tester);
    await tester.tap(find.byTooltip('설정'));
    await _settle(tester);

    expect(find.text('끈질긴 알림'), findsOneWidget);
    expect(find.textContaining('5분마다 최대 3번'), findsOneWidget);
    final nagSwitch = find.descendant(
        of: find.ancestor(of: find.text('끈질긴 알림'), matching: find.byType(Row)).first,
        matching: find.byType(Switch));
    await tester.ensureVisible(nagSwitch); // 관리자 메뉴 아래로 밀려 있을 수 있다
    await tester.pumpAndSettle();
    await tester.tap(nagSwitch);
    await _settle(tester);
    expect(server.nag, isFalse);
    expect(find.text('텔레그램 알림을 한 번만 보내요'), findsOneWidget);
  });
}
