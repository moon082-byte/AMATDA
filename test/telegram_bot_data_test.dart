import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_application_amatda/data/sync_records.dart';

void main() {
  test('텔레그램 봇이 서버에 넣은 할 일 행을 앱이 그대로 읽는다', () {
    final set = emptyRecordSet();
    set['tasks']!['task_1791296028315_k3x9'] = const SyncRecord(
      id: 'task_1791296028315_k3x9',
      position: 3,
      data: '{"title":"보고서 제출","description":null,"isDone":false,'
          '"dueDate":"2026-11-25T15:00:00.000","completedAt":null,"priority":"medium",'
          '"createdAt":"2026-11-24T10:00:00.000","remindAt":[]}',
    );
    final task = fromRecords(set).tasks.single;
    expect(task.title, '보고서 제출');
    expect(task.dueDate, DateTime(2026, 11, 25, 15));
    expect([task.isDone, task.isMissed, task.roomId, task.subTasks], [false, false, null, isEmpty]);
  });
}
