import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'sync_records.dart';

/// 지금 앱 데이터([current])와 서버에 있다고 알고 있는 행([shadow])의 차이:
/// 새로 생기거나 바뀐 행 + 지운 행(삭제 표시). 최대 [max]개.
Map<String, List<SyncRecord>> diffRecords(
  RecordSet current,
  RecordSet shadow, {
  required int max,
}) {
  final result = {for (final t in syncTables) t: <SyncRecord>[]};
  var count = 0;
  for (final t in syncTables) {
    final list = result[t]!;
    for (final r in current[t]!.values) {
      final known = shadow[t]![r.id];
      if (known == null || !known.sameAs(r)) list.add(r);
    }
    for (final known in shadow[t]!.values) {
      if (!current[t]!.containsKey(known.id)) list.add(known.asDeleted());
    }
    if (count + list.length > max) list.removeRange(max - count, list.length);
    count += list.length;
  }
  return result;
}

String encodeRecordSet(RecordSet set) => jsonEncode({
      for (final t in syncTables)
        t: [for (final r in set[t]!.values) r.toJson()],
    });

/// 저장된 행들을 읽는다. 없거나 깨졌으면 null.
RecordSet? decodeRecordSet(String? raw) {
  if (raw == null) return null;
  try {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final set = emptyRecordSet();
    for (final t in syncTables) {
      for (final r in (j[t] as List? ?? const [])) {
        final rec = SyncRecord.fromJson(r as Map<String, dynamic>);
        set[t]![rec.id] = rec;
      }
    }
    return set;
  } catch (e) {
    debugPrint('동기화 상태를 읽지 못해 처음부터 다시 받아요: $e');
    return null;
  }
}
