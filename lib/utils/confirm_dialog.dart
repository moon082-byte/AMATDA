import 'package:flutter/material.dart';

/// 삭제와 같이 되돌리기 어려운 작업 전 확인 다이얼로그를 띄운다
Future<bool> confirmDelete(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('삭제할까요?'),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('취소'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('삭제', style: TextStyle(color: Colors.red)),
        ),
      ],
    ),
  );
  return result ?? false;
}
