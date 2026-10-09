import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_amatda/data/local_store.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/services/auth_service.dart';
import 'support/fake_server.dart';

String _session(bool owner) => '{"token":"tok","user":{"id":"u_1","email":"moondaniel082@gmail.com",'
    '"name":"문","picture":"","owner":$owner}}';

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
  await tester.pumpAndSettle();
}

Future<void> _openSettings(WidgetTester tester, FakeServer server) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final owner = server.user['owner'] == true;
  SharedPreferences.setMockInitialValues({'session_v1': _session(owner)});
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
}

void main() {
  testWidgets('관리자는 설정에서 허용 이메일을 추가하고 지운다', (tester) async {
    final server = FakeServer();
    await _openSettings(tester, server);
    await tester.tap(find.text('허용 이메일 관리'));
    await _settle(tester);
    expect(find.text('moondaniel082@gmail.com'), findsOneWidget);
    expect(find.text('서버 설정 · 여기서 지울 수 없어요'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Friend@Example.com');
    await tester.tap(find.widgetWithText(FilledButton, '추가'));
    await _settle(tester);
    expect(server.allowed, ['friend@example.com']);
    expect(find.text('friend@example.com'), findsOneWidget);
    expect(find.text('허용된 이메일 2개'), findsOneWidget);

    await tester.tap(find.byTooltip('friend@example.com 삭제'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, '삭제'));
    await _settle(tester);
    expect(server.allowed, isEmpty);
    expect(find.text('friend@example.com'), findsNothing);
  });

  testWidgets('관리자가 아니면 관리자 메뉴가 보이지 않는다', (tester) async {
    final server = FakeServer();
    server.user['owner'] = false;
    await _openSettings(tester, server);
    expect(find.text('관리자'), findsNothing);
    expect(find.text('허용 이메일 관리'), findsNothing);
  });
}
