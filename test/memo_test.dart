import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_amatda/data/local_store.dart';
import 'package:flutter_application_amatda/data/sync_records.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/models/memo.dart';
import 'package:flutter_application_amatda/providers/memo_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _boot(WidgetTester tester) async {
  tester.view.physicalSize = const Size(390 * 2, 844 * 2);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
  await tester.tap(find.text('메모'));
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder f) async {
  await tester.tap(f);
  await tester.pumpAndSettle();
}

MemoProvider _memos(WidgetTester tester) =>
    tester.element(find.byType(Scaffold).first).read<MemoProvider>();

Memo _memo(String id, {String title = '', String content = '', DateTime? at, MemoNotion? notion}) {
  final t = at ?? DateTime(2026, 11, 1, 9);
  return Memo(id: id, title: title, content: content, createdAt: t, updatedAt: t, notion: notion);
}

void main() {
  testWidgets('[메모] 탭: 쓰고 → 최신순 목록 → 고치고 → 지우고 실행 취소', (tester) async {
    await _boot(tester);
    expect(find.text('아직 메모가 없어요'), findsOneWidget);
    _memos(tester).addMemo(_memo('old', title: '예전 메모', at: DateTime(2026, 1, 1)));

    await _tap(tester, find.text('새 메모'));
    await _tap(tester, find.text('저장'));
    expect(find.text('제목이나 내용을 적어 주세요'), findsOneWidget, reason: '빈 메모는 저장하지 않는다');
    await tester.enterText(find.byType(TextField).at(0), '회의 아이디어');
    await tester.enterText(find.byType(TextField).at(1), '첫째 줄\n둘째 줄');
    await _tap(tester, find.text('저장'));
    expect(find.text('메모 2개'), findsOneWidget);
    expect(tester.getTopLeft(find.text('회의 아이디어')).dy,
        lessThan(tester.getTopLeft(find.text('예전 메모')).dy), reason: '최신순');

    // 고치기: 바꾸지 않고 닫으면 묻지 않고, 바꾸고 닫으면 확인한다
    await _tap(tester, find.text('회의 아이디어'));
    await tester.enterText(find.byType(TextField).at(0), '회의 아이디어 (수정)');
    await tester.pump();
    await _tap(tester, find.byTooltip('닫기'));
    expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);
    await _tap(tester, find.text('취소'));
    await _tap(tester, find.text('저장'));
    final edited = _memos(tester).latestFirst.first;
    expect([edited.title, edited.content], ['회의 아이디어 (수정)', '첫째 줄\n둘째 줄']);
    expect(edited.updatedAt.isAfter(edited.createdAt) || edited.updatedAt == edited.createdAt, isTrue);

    // 편집 화면에서 삭제 → 확인 → 목록에서 빠지고, 실행 취소하면 돌아온다
    await _tap(tester, find.text('회의 아이디어 (수정)'));
    await _tap(tester, find.byTooltip('삭제'));
    expect(find.textContaining('노션 페이지도 휴지통'), findsOneWidget);
    await _tap(tester, find.widgetWithText(FilledButton, '삭제'));
    expect(find.text('회의 아이디어 (수정)'), findsNothing);
    expect(find.text('메모 1개'), findsOneWidget);
    await _tap(tester, find.text('실행 취소'));
    expect(find.text('회의 아이디어 (수정)'), findsOneWidget);
  });

  test('제목이 없으면 내용 첫 줄이 제목, 고치면 수정 시각이 바뀌고 노션 결과는 남는다', () {
    final m = _memo('m', content: '\n  장보기 목록  \n우유', notion: const MemoNotion(pageId: 'p'));
    expect(m.displayTitle, '장보기 목록');
    expect(_memo('e').displayTitle, '제목 없음');
    final e = m.edited(title: '장보기', content: '우유');
    expect([e.id, e.createdAt, e.notion?.pageId], [m.id, m.createdAt, 'p']);
    expect(e.updatedAt.isAfter(m.updatedAt), isTrue);
  });

  test('노션 반영 상태: 이 수정본이 반영됐는지·실패했는지로 판단한다', () {
    final at = DateTime(2026, 11, 2, 10);
    final v = at.toIso8601String();
    Memo withNotion(MemoNotion n) => _memo('m', at: at, notion: n);
    expect(_memo('m', at: at).notionState(notionOn: false), MemoNotionState.none);
    expect(_memo('m', at: at).notionState(notionOn: true), MemoNotionState.pending);
    expect(withNotion(MemoNotion(pageId: 'p', syncedFor: v)).notionState(notionOn: true),
        MemoNotionState.saved);
    expect(withNotion(const MemoNotion(pageId: 'p', syncedFor: 'older')).notionState(notionOn: true),
        MemoNotionState.pending, reason: '고친 뒤 아직 반영 전');
    expect(withNotion(MemoNotion(pageId: 'p', syncedFor: 'older', error: '권한 없음', errorFor: v))
        .notionState(notionOn: true), MemoNotionState.failed);
  });

  test('동기화 행: memos 표로 오가고, 서버가 적은 노션 결과도 그대로 보존한다', () {
    final memo = _memo('m1', title: '제목', content: '내용',
        notion: const MemoNotion(pageId: 'page1', syncedFor: 'x'));
    final set = toRecords(const [], const [], const [], [memo]);
    final row = set['memos']!['m1']!;
    expect(row.parentId, isNull);
    expect((jsonDecode(row.data) as Map)['notion']['pageId'], 'page1');
    final back = fromRecords(set).memos.single;
    expect([back.title, back.content, back.notion?.pageId, back.notion?.syncedFor],
        ['제목', '내용', 'page1', 'x']);
    expect(back.updatedAt, memo.updatedAt);
    set['memos']!['m1'] = row.asDeleted();
    expect(fromRecords(set).memos, isEmpty);
  });

  test('메모는 계정 저장소에 저장했다가 다시 읽는다', () async {
    SharedPreferences.setMockInitialValues({});
    final store = await LocalStore.open();
    MemoProvider(store: store).addMemo(_memo('m1', title: '저장된 메모'));
    expect(MemoProvider(store: store).memos.single.title, '저장된 메모');
  });
}
