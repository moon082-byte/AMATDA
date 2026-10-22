import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/providers/room_provider.dart';
import 'package:flutter_application_amatda/utils/links.dart';
import 'package:flutter_application_amatda/widgets/composer_frame.dart';
import 'package:provider/provider.dart';

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  test('텔레그램 메시지 링크는 t.me 형식만 받아 https://t.me/... 로 맞춘다', () {
    expect(normalizeTelegramLink(''), '');
    expect(normalizeTelegramLink(' t.me/c/123/45 '), 'https://t.me/c/123/45');
    expect(normalizeTelegramLink('https://telegram.me/team/7'), 'https://t.me/team/7');
    expect(normalizeTelegramLink('https://naver.com/x'), isNull);
    expect(normalizeTelegramLink('t.me'), isNull);
  });

  testWidgets('할 일 추가: [이름][📅] / [링크][🔔] 두 줄, 잘못된 링크는 막고 저장한 링크는 상세에 [텔레그램 열기]', (tester) async {
    tester.view.physicalSize = const Size(390 * 2, 844 * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    // 메인 헤더: 설정 아이콘이 화면 오른쪽 끝(여백 20, 버튼 안쪽 여백 4)에 붙는다
    expect(tester.getTopRight(find.byTooltip('설정')).dx, greaterThanOrEqualTo(390 - 20 - 4));

    await _tap(tester, find.text('오늘 할일').first);
    await _tap(tester, find.text('추가'));
    await _tap(tester, find.text('할 일 추가'));
    final fields = find.descendant(of: find.byType(ComposerFrame), matching: find.byType(TextField));
    expect(fields, findsNWidgets(2));
    expect(tester.getTopLeft(fields.at(1)).dy, greaterThan(tester.getTopLeft(fields.at(0)).dy),
        reason: '링크 칸은 둘째 줄');

    await tester.enterText(fields.at(0), '회의록 공유');
    await tester.enterText(fields.at(1), 'naver.com/abc');
    await tester.pump();
    expect(find.textContaining('t.me 링크만'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, '추가하기')).onPressed, isNull);

    await tester.enterText(fields.at(1), 't.me/c/123/45');
    await tester.pump();
    await _tap(tester, find.text('추가하기'));
    final rooms = tester.element(find.byType(Scaffold).first).read<RoomProvider>();
    final added = rooms.tasks.firstWhere((t) => t.title == '회의록 공유');
    expect(added.link, 'https://t.me/c/123/45');

    await tester.scrollUntilVisible(find.text('회의록 공유'), 300,
        scrollable: find.descendant(of: find.byType(CustomScrollView).last, matching: find.byType(Scrollable)).first);
    await _tap(tester, find.text('회의록 공유'));
    expect(find.text('텔레그램 열기'), findsOneWidget);
  });
}
