import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_application_amatda/data/local_store.dart';
import 'package:flutter_application_amatda/data/model_json.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/models/task_item.dart';
import 'package:flutter_application_amatda/services/auth_service.dart';
import 'package:flutter_application_amatda/services/launch_link.dart';
import 'support/fake_server.dart';

const _ack = 'abababababababababababab';

Future<(LocalStore, AuthService)> _auth(FakeServer server) async {
  final store = await LocalStore.open();
  return (store, AuthService(store: store, client: server.client, apiUrl: 'https://api.test'));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugSetLaunchTarget(null);
  });

  test('[앱에서 보기]로 왔다가 로그인하러 떠나도, 돌아오면 그 항목을 연다', () async {
    final (store, auth) = await _auth(FakeServer());
    debugSetLaunchTarget((kind: 'task', id: 't9'), ack: _ack);
    await store.savePendingLaunch(pendingLaunchValue()!); // signIn()이 떠나기 전에 하는 일
    debugSetLaunchTarget(null); // 페이지를 떠나면 메모리는 사라진다

    await auth.init(loginCode: 'login-ok');
    expect(takeLaunchTarget(), (kind: 'task', id: 't9'));
    expect(takeLaunchAck(), _ack, reason: '끈질긴 알림 확인값도 함께 기억한다');
    expect(store.takePendingLaunch(), isNull, reason: '한 번 쓰면 지운다');
  });

  test('로그인에서 돌아온 게 아니거나 30분이 지났으면 기억한 항목을 버린다', () async {
    final (store, auth) = await _auth(FakeServer());
    await store.savePendingLaunch('task:t9');
    await auth.init(); // 그냥 앱을 다시 연 경우
    expect(takeLaunchTarget(), isNull);
    expect(store.takePendingLaunch(), isNull);

    await store.savePendingLaunch('task:t9');
    final later = DateTime.now().add(const Duration(minutes: 31));
    expect(store.takePendingLaunch(now: later), isNull);
  });

  testWidgets('처음 로그인한 기기에서도 동기화를 기다렸다가 할 일을 펼쳐서 열고, 끈질긴 알림을 끈다', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    // 다른 기기에서 만든 할 일 (이 기기에는 아직 없음, 업무방 없음)
    final server = FakeServer();
    final task = TaskItem(
      id: 't9',
      title: '서버에만 있는 할 일',
      dueDate: DateTime.now().add(const Duration(days: 1)),
      createdAt: DateTime.now(),
    );
    server.tables['tasks']!['t9'] = {
      'id': 't9',
      'parentId': null,
      'position': 0,
      'data': jsonEncode(taskToJson(task)),
      'deleted': false,
      'version': ++server.version,
    };
    debugSetLaunchTarget((kind: 'task', id: 't9'), ack: _ack);
    final (store, auth) = await tester.runAsync(() => _auth(server)).then((v) => v!);
    await tester.runAsync(() => auth.init(loginCode: 'login-ok'));

    await tester.pumpWidget(MyApp(store: store, auth: auth));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
      await tester.pumpAndSettle();
    }
    expect(find.text('서버에만 있는 할 일'), findsWidgets);
    expect(find.text('세부 체크리스트'), findsOneWidget, reason: '할 일이 펼쳐져 있다');
    expect(find.textContaining('진행 중인 할 일'), findsOneWidget); // 오늘 할일 화면
    expect(server.acks, [_ack]);
  });
}
