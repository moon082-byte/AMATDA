import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_amatda/data/local_store.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/services/auth_service.dart';
import 'support/fake_server.dart';

const _session = '{"token":"tok","user":{"id":"u_1","email":"moondaniel082@gmail.com",'
    '"name":"문","picture":"","owner":false}}';

/// 로그인한 채로 앱을 열고 설정 화면으로 간다
Future<void> _openSettings(WidgetTester tester, FakeServer server) async {
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
  await tester.tap(find.byTooltip('설정'));
  await tester.pumpAndSettle();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 20)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('텔레그램이 연결돼 있지 않으면 업무방 링크 칸은 보이지 않는다', (tester) async {
    await _openSettings(tester, FakeServer());
    expect(find.text('텔레그램 알림'), findsOneWidget);
    expect(find.text('텔레그램 업무방 링크'), findsNothing);
  });

  testWidgets('설정에서 텔레그램 업무방 링크를 저장하고 지운다', (tester) async {
    final server = FakeServer()..telegramLinked = true;
    await _openSettings(tester, server);
    expect(find.text('알림에 넣을 업무방 링크를 입력해 주세요'), findsOneWidget);

    await tester.tap(find.text('텔레그램 업무방 링크'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'ftp://team');
    await tester.tap(find.text('저장'));
    await _settle(tester);
    expect(find.text('http(s)로 시작하는 주소를 넣어 주세요'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 't.me/+team');
    await tester.tap(find.text('저장'));
    await _settle(tester);
    expect(server.roomUrl, 'https://t.me/+team');
    expect(find.text('https://t.me/+team'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5)); // 저장 안내 배너가 사라질 때까지
    await tester.pumpAndSettle();

    await tester.tap(find.text('텔레그램 업무방 링크'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지우기'));
    await _settle(tester);
    expect(server.roomUrl, '');
    expect(find.text('알림에 넣을 업무방 링크를 입력해 주세요'), findsOneWidget);
  });
}
