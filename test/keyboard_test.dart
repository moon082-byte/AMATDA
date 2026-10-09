import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_amatda/main.dart';
import 'package:flutter_application_amatda/services/launch_link.dart';

Finder _addField(String hint) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.hintText == hint);

void main() {
  testWidgets('키보드가 떠 있는 채로 세부 항목·메모를 여러 개 추가해도 입력칸은 키보드 위에 있다', (tester) async {
    const height = 844.0, keyboard = 340.0;
    tester.view.physicalSize = const Size(390 * 2, height * 2);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    debugSetLaunchTarget((kind: 'task', id: 'task_001')); // 할 일을 펼친 채로 연다
    await tester.pumpWidget(const MyApp());
    await tester.pumpAndSettle();

    for (final hint in ['세부 항목 추가', '메모를 남겨보세요']) {
      await tester.ensureVisible(_addField(hint));
      await tester.tap(_addField(hint));
      tester.view.viewInsets = const FakeViewPadding(bottom: keyboard * 2); // 키보드가 올라옴
      await tester.pumpAndSettle();
      for (var i = 1; i <= 8; i++) {
        await tester.enterText(_addField(hint), '$hint $i');
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();
        expect(tester.getRect(_addField(hint)).bottom, lessThanOrEqualTo(height - keyboard),
            reason: '$hint: $i개째 추가 후에도 입력칸이 키보드에 가리지 않는다');
      }
      tester.view.resetViewInsets();
      await tester.pumpAndSettle();
    }
  });
}
