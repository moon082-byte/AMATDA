import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../theme/app_palette.dart';

/// 가로로 넘기는 목록. 마우스로도 끌어서 넘길 수 있고,
/// PC(Windows·Mac·Linux)에서는 양옆에 ◀ ▶ 버튼을 보여준다(끝까지 가면 그쪽 버튼은 숨김).
class HorizontalScroller extends StatefulWidget {
  /// [controller]를 붙인 가로 목록을 만든다
  final Widget Function(ScrollController controller) builder;

  /// 버튼 표시 여부를 직접 정할 때 (테스트용). 없으면 PC에서만 보인다.
  final bool? showArrows;

  const HorizontalScroller({super.key, required this.builder, this.showArrows});

  @override
  State<HorizontalScroller> createState() => _HorizontalScrollerState();
}

class _HorizontalScrollerState extends State<HorizontalScroller> {
  final _controller = ScrollController();

  static bool get _isDesktop => switch (defaultTargetPlatform) {
    TargetPlatform.windows ||
    TargetPlatform.macOS ||
    TargetPlatform.linux => true,
    _ => false,
  };

  @override
  void initState() {
    super.initState();
    _controller.addListener(_update);
    // 처음 그린 뒤 목록 길이를 알아야 오른쪽 버튼을 보일지 정할 수 있다
    WidgetsBinding.instance.addPostFrameCallback((_) => _update());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _update() {
    if (mounted) setState(() {});
  }

  /// 화면 폭의 80%만큼 넘긴다
  void _page(int direction) {
    final position = _controller.position;
    final target =
        (position.pixels + direction * position.viewportDimension * 0.8).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        );
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final arrows = widget.showArrows ?? _isDesktop;
    final ready =
        _controller.hasClients && _controller.position.hasContentDimensions;
    final canBack = ready && _controller.position.extentBefore > 1;
    final canForward = ready && _controller.position.extentAfter > 1;

    return Stack(
      children: [
        ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
            },
          ),
          child: widget.builder(_controller),
        ),
        if (arrows && canBack)
          Positioned(
            left: 4,
            top: 0,
            bottom: 0,
            child: _Arrow(back: true, onTap: () => _page(-1)),
          ),
        if (arrows && canForward)
          Positioned(
            right: 4,
            top: 0,
            bottom: 0,
            child: _Arrow(back: false, onTap: () => _page(1)),
          ),
      ],
    );
  }
}

class _Arrow extends StatelessWidget {
  final bool back;
  final VoidCallback onTap;

  const _Arrow({required this.back, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Center(
      child: Material(
        color: palette.card,
        shape: const CircleBorder(),
        elevation: 3,
        shadowColor: Colors.black26,
        child: IconButton(
          onPressed: onTap,
          tooltip: back ? '이전 업무방' : '다음 업무방',
          icon: Icon(
            back ? Icons.chevron_left_rounded : Icons.chevron_right_rounded,
            color: palette.titleText,
          ),
        ),
      ),
    );
  }
}
