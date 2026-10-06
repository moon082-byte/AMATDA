import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_amatda/data/local_store.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/providers/room_provider.dart';
import 'package:flutter_application_amatda/services/auth_service.dart';
import 'package:provider/provider.dart';
import 'support/fake_server.dart';

Future<(LocalStore, AuthService)> _auth(FakeServer server) async {
  final store = await LocalStore.open();
  return (store, AuthService(store: store, client: server.client, apiUrl: 'https://api.test'));
}

const _session = '{"token":"tok","user":{"id":"u_1","email":"moondaniel082@gmail.com",'
    '"name":"문","picture":"","owner":true}}';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('로그인 상태', () {
    test('구글에서 돌아온 일회용 코드를 토큰으로 바꾸고 저장한다', () async {
      final (store, auth) = await _auth(FakeServer());
      await auth.init(loginCode: 'login-ok');
      expect(auth.status, AuthStatus.signedIn);
      expect(auth.user!.email, 'moondaniel082@gmail.com');
      expect(auth.user!.owner, isTrue);
      expect(store.loadSession()!.token, 'tok');
    });

    test('만료된 코드나 허용 안 된 계정이면 로그인 화면에 이유를 보여준다', () async {
      final (_, auth) = await _auth(FakeServer());
      await auth.init(loginCode: 'expired');
      expect(auth.status, AuthStatus.signedOut);
      expect(auth.error, contains('만료'));

      final (_, denied) = await _auth(FakeServer());
      await denied.init(loginError: 'not_allowed');
      expect(denied.status, AuthStatus.signedOut);
      expect(denied.error, contains('허용되지 않은 계정'));
    });

    test('저장된 로그인은 오프라인이어도 유지되고, 서버가 거부하면 로그아웃된다', () async {
      SharedPreferences.setMockInitialValues({'session_v1': _session});
      final server = FakeServer()..offline = true;
      final (_, auth) = await _auth(server);
      await auth.init();
      expect(auth.status, AuthStatus.signedIn);

      SharedPreferences.setMockInitialValues({
        'session_v1': _session.replaceFirst('"tok"', '"old"'),
      });
      final (store, expired) = await _auth(FakeServer());
      await expired.init();
      expect(expired.status, AuthStatus.signedOut);
      expect(store.loadSession(), isNull);
    });

    test('로그아웃하면 저장된 로그인을 지운다', () async {
      SharedPreferences.setMockInitialValues({'session_v1': _session});
      final (store, auth) = await _auth(FakeServer());
      await auth.init();
      await auth.signOut();
      expect(auth.status, AuthStatus.signedOut);
      expect(store.loadSession(), isNull);
    });
  });

  testWidgets('로그인하지 않으면 로그인 화면만 보인다', (tester) async {
    final (store, auth) = await tester.runAsync(() => _auth(FakeServer())).then((v) => v!);
    await tester.runAsync(() => auth.init());
    await tester.pumpWidget(MyApp(store: store, auth: auth));
    await tester.pump();
    expect(find.text('Google 계정으로 로그인'), findsOneWidget);
    expect(find.text('오늘 할일'), findsNothing);
  });

  testWidgets('주인 계정으로 처음 로그인하면 이 기기의 예전 데이터를 가져올지 묻는다', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // 로그인 전 예전 앱이 저장해 둔 데이터 (샘플 업무방 3개·할 일 3개)
    final sample = RoomProvider();
    final server = FakeServer();
    final (store, auth) = await tester.runAsync(() async {
      final root = await LocalStore.open();
      await root.saveData(sample.rooms, sample.tasks);
      return _auth(server);
    }).then((v) => v!);
    await tester.runAsync(() => auth.init(loginCode: 'login-ok'));

    await tester.pumpWidget(MyApp(store: store, auth: auth));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pumpAndSettle();
    expect(find.text('이 기기의 기존 데이터를 가져올까요?'), findsOneWidget);
    expect(find.textContaining('업무방 3개 · 할 일 3개'), findsOneWidget);

    await tester.tap(find.text('가져오기'));
    await tester.pumpAndSettle();
    final rooms = tester.element(find.byType(Scaffold).first).read<RoomProvider>();
    expect(rooms.rooms, hasLength(3));
    expect(store.legacyImportAsked, isTrue);

    // 2초 뒤 계정(서버)으로 올라간다
    await tester.pump(const Duration(seconds: 3));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
    expect(server.ids('rooms'), hasLength(3));
    expect(server.ids('sub_tasks'), hasLength(3));
  });
}
