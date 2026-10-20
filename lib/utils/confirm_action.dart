import 'package:flutter/material.dart';
import '../services/api_client.dart';
import '../theme/app_typography.dart';

/// [확인]/[취소] 다이얼로그 (삭제가 아닌 일반 확인용). 확인하면 true.
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  String? message,
  String confirmLabel = '확인',
}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title, style: ctx.text.h2),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// 서버 요청을 실행하고, 실패하면 이유를 아래 알림줄로 보여준다. 성공하면 결과, 실패하면 null.
Future<T?> runWithMessage<T>(BuildContext context, Future<T> Function() request) async {
  try {
    return await request();
  } on ApiException catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.isOffline ? '인터넷 연결 후 다시 시도해 주세요' : e.message),
      ));
    }
    return null;
  }
}
