import 'package:flutter/foundation.dart';
import '../data/local_store.dart';
import '../data/sample_data.dart';
import '../models/routine.dart';

/// 루틴(습관) 목록과 날짜별 완료 기록을 관리한다.
/// [store](계정별 저장소)가 있으면 바뀔 때마다 저장하고, 새 계정은 빈 상태로 시작한다.
/// [store]가 없으면(테스트·미리보기) 샘플 루틴으로 시작한다.
class RoutineProvider extends ChangeNotifier {
  final LocalStore? _store;
  final List<Routine> _routines;

  RoutineProvider({LocalStore? store})
      : _store = store,
        _routines = store == null ? buildMockRoutines() : store.loadRoutines() ?? [];

  /// 상태가 바뀔 때마다 저장소에도 기록한다
  @override
  void notifyListeners() {
    _store?.saveRoutines(_routines);
    super.notifyListeners();
  }

  List<Routine> get routines => List.unmodifiable(_routines);

  Routine? routineById(String id) =>
      _routines.where((r) => r.id == id).firstOrNull;

  /// [day]에 해야 하는 루틴 (시각 순)
  List<Routine> routinesOn(DateTime day) =>
      _routines.where((r) => r.occursOn(day)).toList()
        ..sort(
          (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
        );

  void addRoutine(Routine routine) {
    _routines.add(routine);
    notifyListeners();
  }

  void updateRoutine(Routine updated) => _edit(updated.id, (_) => updated);

  /// 루틴을 지우고, 되돌릴 때 쓸 원래 위치를 돌려준다 (없으면 -1)
  int deleteRoutine(String id) {
    final index = _routines.indexWhere((r) => r.id == id);
    if (index == -1) return -1;
    _routines.removeAt(index);
    notifyListeners();
    return index;
  }

  /// 삭제를 되돌릴 때 원래 자리에 다시 넣는다
  void restoreRoutine(Routine routine, int index) {
    if (routineById(routine.id) != null) return;
    _routines.insert(index.clamp(0, _routines.length), routine);
    notifyListeners();
  }

  void toggleDone(String id, DateTime day) =>
      _edit(id, (r) => r.toggledOn(day));

  /// 모든 루틴을 지운다
  void clearAll() => replaceAll(const []);

  /// 목록 전체를 바꾼다 (다른 기기에서 받은 데이터 반영)
  void replaceAll(List<Routine> routines) {
    _routines
      ..clear()
      ..addAll(routines);
    notifyListeners();
  }

  /// 없는 루틴만 덧붙이고 개수를 돌려준다
  int mergeMissing(List<Routine> routines) {
    final added = routines.where((r) => routineById(r.id) == null).toList();
    _routines.addAll(added);
    notifyListeners();
    return added.length;
  }

  void _edit(String id, Routine Function(Routine) change) {
    final index = _routines.indexWhere((r) => r.id == id);
    if (index == -1) return;
    _routines[index] = change(_routines[index]);
    notifyListeners();
  }
}
