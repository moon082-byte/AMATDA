import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/local_store.dart';
import '../services/api_client.dart';
import '../services/pin_service.dart';
import '../views/login_view.dart';
import '../views/pin_lock_view.dart';

/// 로그인 다음 관문: PIN을 켠 계정이면 앱을 열 때마다 PIN을 입력해야 [child]를 보여준다.
/// 다른 기기에서 PIN을 켜거나 바꾸면(서버 423) 쓰는 중에도 다시 잠근다.
class PinGate extends StatefulWidget {
  final ApiClient api;

  /// 계정 저장소 (PIN 사용 여부를 기억해 오프라인일 때 판단)
  final LocalStore store;
  final Widget child;

  const PinGate({
    super.key,
    required this.api,
    required this.store,
    required this.child,
  });

  @override
  State<PinGate> createState() => _PinGateState();
}

class _PinGateState extends State<PinGate> {
  late final PinService _pin = PinService(api: widget.api, store: widget.store);

  @override
  void initState() {
    super.initState();
    widget.api.onPinRequired = _pin.requireAgain;
    _pin.load();
  }

  @override
  void dispose() {
    if (widget.api.onPinRequired == _pin.requireAgain) {
      widget.api.onPinRequired = null;
    }
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _pin,
      child: Consumer<PinService>(
        builder: (context, pin, _) => switch (pin.status) {
          PinStatus.unlocked => widget.child,
          PinStatus.checking => const LoginView(checking: true),
          PinStatus.locked || PinStatus.offline => const PinLockView(),
        },
      ),
    );
  }
}
