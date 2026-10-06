import 'dart:math';

final _random = Random.secure();
const _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// 새 항목 id. 여러 기기에서 동시에 만들어도 겹치지 않게 시각 뒤에 무작위 글자를 붙인다.
/// 예) task_1791296028315_k3x9
String newId(String prefix) {
  final suffix =
      List.generate(4, (_) => _chars[_random.nextInt(_chars.length)]).join();
  return '${prefix}_${DateTime.now().millisecondsSinceEpoch}_$suffix';
}
