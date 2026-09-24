import 'package:flutter/material.dart';

/// 날짜 → 시간 순으로 선택 창을 띄워 마감 일시를 고른다.
/// 날짜 선택을 취소하면 null, 시간 선택만 취소하면 자정(00:00)으로 둔다.
Future<DateTime?> pickDateTime(BuildContext context, {DateTime? initial}) async {
  final now = DateTime.now();
  final date = await showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: now.subtract(const Duration(days: 365)),
    lastDate: now.add(const Duration(days: 365 * 2)),
    helpText: '마감 날짜 선택',
    cancelText: '취소',
    confirmText: '다음',
  );
  if (date == null || !context.mounted) return null;

  final time = await showTimePicker(
    context: context,
    initialTime: initial != null
        ? TimeOfDay.fromDateTime(initial)
        : const TimeOfDay(hour: 18, minute: 0),
    helpText: '마감 시간 선택',
    cancelText: '시간 없음',
    confirmText: '확인',
  );
  return DateTime(
    date.year,
    date.month,
    date.day,
    time?.hour ?? 0,
    time?.minute ?? 0,
  );
}
