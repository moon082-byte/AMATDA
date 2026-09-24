import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';

/// 삭제와 같이 되돌리기 어려운 작업 전 확인 다이얼로그를 띄운다
Future<bool> confirmDelete(BuildContext context, String message) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) {
      final palette = ctx.palette;
      final text = ctx.text;
      final buttonShape = RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      );

      return Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('삭제할까요?', style: text.h2),
              const SizedBox(height: 8),
              Text(message, style: text.body),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.fill,
                        foregroundColor: palette.bodyText,
                        minimumSize: const Size.fromHeight(50),
                        shape: buttonShape,
                      ),
                      child: const Text('취소'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: FilledButton.styleFrom(
                        backgroundColor: palette.danger,
                        minimumSize: const Size.fromHeight(50),
                        shape: buttonShape,
                      ),
                      child: const Text('삭제'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
  return result ?? false;
}
