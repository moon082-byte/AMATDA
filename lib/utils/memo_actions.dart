import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/memo.dart';
import '../providers/memo_provider.dart';
import 'task_actions.dart';

/// 메모를 지우고, 알림줄의 [실행 취소]로 원래 자리에 되돌릴 수 있게 한다.
/// (동기화되면 노션 연동 중인 계정은 노션 페이지도 휴지통으로 간다)
void deleteMemoWithUndo(BuildContext context, Memo memo) {
  final provider = context.read<MemoProvider>();
  final index = provider.deleteMemo(memo.id);
  if (index < 0) return;
  showUndoSnackBar(context, '"${memo.displayTitle}" 메모를 지웠어요',
      () => provider.insertMemo(memo, index));
}
