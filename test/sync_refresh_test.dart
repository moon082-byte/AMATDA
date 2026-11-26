import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter_application_amatda/data/local_store.dart';
import 'package:flutter_application_amatda/providers/room_provider.dart';
import 'package:flutter_application_amatda/providers/routine_provider.dart';
import 'package:flutter_application_amatda/services/api_client.dart';
import 'package:flutter_application_amatda/services/app_update.dart';
import 'package:flutter_application_amatda/services/sync_scheduler.dart';
import 'package:flutter_application_amatda/services/sync_service.dart';
import 'package:flutter_application_amatda/widgets/refresh_button.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'support/fake_server.dart';

/// 앱 상태 바꾸기: 화면 → 다른 앱(숨김) → 다시 돌아옴
Future<void> _lifecycle(WidgetTester tester, List<AppLifecycleState> states) async {
  for (final s in states) {
    tester.binding.handleAppLifecycleStateChanged(s);
    await tester.pump();
  }
}

void main() {
  testWidgets('동기화 시점: 바뀌면 2초 뒤, 숨겨져 있으면 쉬고, 떠날 때 남은 변경을 바로, 돌아오면 바로', (tester) async {
    var calls = 0;
    final changes = ChangeNotifier();
    final scheduler = SyncScheduler(sync: () async => calls++, changes: changes, applying: () => false)..start();

    changes.notifyListeners();
    changes.notifyListeners();
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 0);
    await tester.pump(const Duration(seconds: 1));
    expect(calls, 1, reason: '연속 변경은 2초 뒤 한 번에');

    await tester.pump(SyncScheduler.interval);
    expect(calls, 2, reason: '보이는 동안 30초마다');

    // 고치고 2초가 지나기 전에 앱을 떠나면 바로 올린다
    changes.notifyListeners();
    await _lifecycle(tester, [AppLifecycleState.inactive, AppLifecycleState.hidden]);
    expect(calls, 3);
    await tester.pump(SyncScheduler.interval * 3);
    expect(calls, 3, reason: '숨겨져 있는 동안은 쉰다');

    // 앱으로 돌아오면 바로 받는다
    await _lifecycle(tester, [AppLifecycleState.inactive, AppLifecycleState.resumed]);
    expect(calls, 4);
    scheduler.dispose();
  });

  testWidgets('🔄 새로고침: 누르면 서버와 맞추는 동안 로딩 표시, 끝나면 다시 버튼', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final server = FakeServer();
    final slow = MockClient((req) async {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      final copy = http.Request(req.method, req.url)
        ..headers.addAll(req.headers)
        ..bodyBytes = req.bodyBytes;
      return server.client.send(copy).then(http.Response.fromStream);
    });
    final store = (await LocalStore.open()).forUser('u_1:a');
    final api = ApiClient(baseUrl: 'https://api.test', token: () => 'tok', client: slow);
    final sync = SyncService(api: api, store: store, rooms: RoomProvider(store: store), routines: RoutineProvider(store: store));
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: sync,
      child: const MaterialApp(home: Scaffold(body: Center(child: RefreshButton()))),
    ));

    await tester.tap(find.byTooltip('새로고침'));
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byTooltip('새로 받는 중'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(server.syncCalls, 1);
    expect(sync.lastSyncedAt, isNotNull);
    sync.dispose();
  });

  test('새 버전 감지: 배포된 빌드 번호가 다르면 알린다 (빌드 번호가 없으면 확인하지 않는다)', () async {
    var deployed = 'abc';
    final asked = <Uri>[];
    final client = MockClient((req) async {
      asked.add(req.url);
      return http.Response(jsonEncode({'build': deployed}), 200);
    });
    final same = AppUpdate(current: 'abc', client: client);
    await same.check();
    expect(same.available, isFalse);
    expect(asked.single.path, endsWith('build.json'));
    expect(asked.single.queryParameters['t'], isNotNull, reason: '캐시된 예전 파일을 받지 않게');

    deployed = 'def';
    await same.check();
    expect([same.available, same.latest], [true, 'def']);

    final dev = AppUpdate(current: '', client: client);
    await dev.check();
    expect([dev.enabled, dev.available, asked.length], [false, false, 2]);
  });
}
