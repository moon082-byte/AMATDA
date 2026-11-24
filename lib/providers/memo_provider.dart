import 'package:flutter/foundation.dart';
import '../data/local_store.dart';
import '../models/memo.dart';

/// 메모 목록. [store](계정별 저장소)가 있으면 바뀔 때마다 저장한다 (없으면 테스트·미리보기용 빈 목록).
/// 동기화되면 서버가 노션 연동을 켠 계정의 메모를 노션 1_Inbox에 반영한다.
class MemoProvider extends ChangeNotifier {
  final LocalStore? _store;
  final List<Memo> _memos;

  MemoProvider({LocalStore? store})
      : _store = store,
        _memos = store?.loadMemos() ?? [];

  @override
  void notifyListeners() {
    _store?.saveMemos(_memos);
    super.notifyListeners();
  }

  /// 저장된 순서 그대로 (동기화용)
  List<Memo> get memos => List.unmodifiable(_memos);

  /// 최근에 고친 메모부터
  List<Memo> get latestFirst =>
      [..._memos]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  Memo? memoById(String id) => _memos.where((m) => m.id == id).firstOrNull;

  void addMemo(Memo memo) {
    _memos.add(memo);
    notifyListeners();
  }

  void updateMemo(Memo updated) {
    final i = _memos.indexWhere((m) => m.id == updated.id);
    if (i == -1) return;
    _memos[i] = updated;
    notifyListeners();
  }

  /// 메모를 지우고, 되돌릴 때 쓸 원래 위치를 돌려준다 (없으면 -1)
  int deleteMemo(String id) {
    final i = _memos.indexWhere((m) => m.id == id);
    if (i == -1) return -1;
    _memos.removeAt(i);
    notifyListeners();
    return i;
  }

  void insertMemo(Memo memo, int index) {
    if (_memos.any((m) => m.id == memo.id)) return;
    _memos.insert(index.clamp(0, _memos.length), memo);
    notifyListeners();
  }

  /// 다른 기기에서 받은 내용으로 통째로 바꾼다 (동기화)
  void replaceAll(List<Memo> memos) {
    _memos
      ..clear()
      ..addAll(memos);
    notifyListeners();
  }
}
