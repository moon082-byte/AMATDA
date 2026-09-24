import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_application_amatda/main.dart';

void main() {
  testWidgets('메인 대시보드가 요약 타일과 함께 표시된다', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    expect(find.text('오늘 할일'), findsOneWidget);
    expect(find.text('완료된 일들'), findsOneWidget);
    expect(find.byTooltip('설정'), findsOneWidget);
  });

  testWidgets('오늘 할일 타일을 누르면 업무방 목록 화면으로 이동한다', (tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('오늘 할일'));
    await tester.pumpAndSettle();

    expect(find.text('텔레그램 업무방'), findsOneWidget);
    expect(find.text('새 업무방'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new_rounded), findsOneWidget);
  });
}
