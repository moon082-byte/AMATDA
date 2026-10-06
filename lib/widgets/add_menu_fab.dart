import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import 'add_menu_item.dart';

/// '추가' 버튼. 누르면 위로 [할 일 추가][루틴 추가] 메뉴가 펼쳐진다.
class AddMenuFab extends StatelessWidget {
  final VoidCallback onAddTask;
  final VoidCallback onAddRoutine;

  const AddMenuFab({
    super.key,
    required this.onAddTask,
    required this.onAddRoutine,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await showGeneralDialog<VoidCallback>(
      context: context,
      barrierDismissible: true,
      barrierLabel: '닫기',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 200),
      pageBuilder: (context, _, _) =>
          _AddMenu(onAddTask: onAddTask, onAddRoutine: onAddRoutine),
      transitionBuilder: (context, animation, _, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        );
        return FadeTransition(
          opacity: curved,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(curved),
            child: child,
          ),
        );
      },
    );
    // 메뉴가 완전히 닫힌 뒤 입력 화면을 연다
    picked?.call();
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return FloatingActionButton.extended(
      onPressed: () => _open(context),
      backgroundColor: palette.accent,
      foregroundColor: Colors.white,
      elevation: 2,
      shape: const StadiumBorder(),
      icon: const Icon(Icons.add_rounded),
      label: const Text('추가', style: TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// 추가 버튼 위로 펼쳐지는 메뉴. 아래쪽 닫기 버튼은 추가 버튼과 같은 자리에 놓인다.
class _AddMenu extends StatelessWidget {
  final VoidCallback onAddTask;
  final VoidCallback onAddRoutine;

  const _AddMenu({required this.onAddTask, required this.onAddRoutine});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Align(
          alignment: Alignment.bottomRight,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              AddMenuItem(
                label: '루틴 추가',
                icon: Icons.repeat_rounded,
                color: palette.routine,
                softColor: palette.routineSoft,
                onTap: () => Navigator.pop(context, onAddRoutine),
              ),
              const SizedBox(height: 10),
              AddMenuItem(
                label: '할 일 추가',
                icon: Icons.checklist_rounded,
                color: palette.accent,
                softColor: palette.accentSoft,
                onTap: () => Navigator.pop(context, onAddTask),
              ),
              const SizedBox(height: 14),
              FloatingActionButton.extended(
                heroTag: null,
                onPressed: () => Navigator.pop(context),
                backgroundColor: palette.card,
                foregroundColor: palette.titleText,
                elevation: 2,
                shape: const StadiumBorder(),
                icon: const Icon(Icons.close_rounded),
                label: const Text(
                  '닫기',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
