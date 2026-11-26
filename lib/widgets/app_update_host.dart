import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/app_update.dart';

/// 새 버전이 배포되면 화면 위에 "새 버전이 있어요 [새로고침]" 알림줄을 띄운다.
/// 바로 다시 불러오지 않아 입력 중인 내용이 날아가지 않는다.
class AppUpdateHost extends StatefulWidget {
  final Widget child;
  const AppUpdateHost({super.key, required this.child});

  @override
  State<AppUpdateHost> createState() => _AppUpdateHostState();
}

class _AppUpdateHostState extends State<AppUpdateHost> {
  late final AppUpdate _update = context.read<AppUpdate>();
  bool _shown = false;

  @override
  void initState() {
    super.initState();
    _update.addListener(_changed);
  }

  @override
  void dispose() {
    _update.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!_update.available || _shown || !mounted) return;
    _shown = true;
    final messenger = ScaffoldMessenger.of(context);
    messenger.showMaterialBanner(MaterialBanner(
      leading: const Icon(Icons.system_update_rounded),
      content: const Text('새 버전이 있어요. 새로고침하면 최신 기능을 쓸 수 있어요.'),
      actions: [
        TextButton(onPressed: messenger.hideCurrentMaterialBanner, child: const Text('나중에')),
        TextButton(
          onPressed: _update.reload,
          child: const Text('새로고침', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      ],
    ));
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
