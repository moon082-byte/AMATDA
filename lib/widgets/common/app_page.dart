import 'package:flutter/material.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_typography.dart';

/// 하위 화면 공통 틀. 상단 바(뒤로가기·액션)는 항상 고정되고,
/// 큰 제목은 스크롤하면 상단 바 안의 작은 제목으로 접힌다.
class AppPage extends StatelessWidget {
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  final List<Widget> slivers;
  final Widget? floatingActionButton;

  /// 입력 화면용: 닫기(X) 아이콘과 흰 배경(회색 입력칸이 잘 보이도록)을 쓴다
  final bool closeIcon;

  const AppPage({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
    required this.slivers,
    this.floatingActionButton,
    this.closeIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final background = closeIcon ? palette.card : palette.background;

    return Scaffold(
      backgroundColor: background,
      floatingActionButton: floatingActionButton,
      body: CustomScrollView(
        slivers: [
          SliverAppBar.large(
            pinned: true,
            backgroundColor: background,
            surfaceTintColor: Colors.transparent,
            scrolledUnderElevation: 0,
            automaticallyImplyLeading: false,
            leadingWidth: 64,
            leading: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: IconButton(
                onPressed: () => Navigator.maybePop(context),
                tooltip: closeIcon ? '닫기' : '뒤로',
                iconSize: 24,
                style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: Icon(
                  closeIcon
                      ? Icons.close_rounded
                      : Icons.arrow_back_ios_new_rounded,
                  color: palette.titleText,
                ),
              ),
            ),
            title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
            actions: [...actions, const SizedBox(width: 8)],
          ),
          if (subtitle != null)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              sliver: SliverToBoxAdapter(
                child: Text(
                  subtitle!,
                  style: text.body.copyWith(color: palette.subText),
                ),
              ),
            ),
          ...slivers,
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

/// 화면 좌우 여백(20)을 둔 일반 위젯 목록
Widget paddedSliver(List<Widget> children, {double top = 0}) {
  return SliverPadding(
    padding: EdgeInsets.fromLTRB(20, top, 20, 0),
    sliver: SliverList.list(children: children),
  );
}

/// 입력 화면 상단 바 오른쪽의 '저장' 버튼 (입력이 부족하면 [onPressed]를 null로)
Widget saveAction(VoidCallback? onPressed) {
  return TextButton(
    onPressed: onPressed,
    child: const Text('저장', style: TextStyle(fontSize: 16)),
  );
}
