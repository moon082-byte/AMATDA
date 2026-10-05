import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/local_store.dart';
import '../providers/notification_provider.dart';
import '../providers/room_provider.dart';
import '../services/browser_notifications.dart';
import '../services/telegram_link.dart';
import '../services/reminder_checker.dart';
import 'reminder_banner.dart';

/// 앱 전체를 감싸 리마인드 시각이 되면 알림을 띄운다.
/// 화면이 보이면 상단 배너, 다른 탭/앱으로 가 있으면 브라우저 알림을 보낸다.
/// (앱을 완전히 닫으면 울리지 않는다. 다시 열면 놓친 알림을 보여준다.)
class ReminderHost extends StatefulWidget {
  final LocalStore? store;
  final Widget child;

  const ReminderHost({super.key, this.store, required this.child});

  @override
  State<ReminderHost> createState() => _ReminderHostState();
}

class _ReminderHostState extends State<ReminderHost>
    with WidgetsBindingObserver {
  late final Set<String> _fired = widget.store?.loadFiredReminders() ?? {};
  Timer? _ticker;
  Timer? _autoHide;
  List<DueReminder> _showing = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ticker = Timer.periodic(const Duration(seconds: 20), (_) => _check());
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _autoHide?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  void _check() {
    if (!mounted || !context.read<NotificationProvider>().enabled) return;
    final provider = context.read<RoomProvider>();
    final due = collectDueReminders(
      tasks: provider.tasks,
      rooms: provider.rooms,
      now: DateTime.now(),
      fired: _fired,
    );
    if (due.isEmpty) return;

    _fired.addAll([for (final r in due) ...r.alsoCovers, for (final r in due) r.key]);
    widget.store?.saveFiredReminders(_fired);
    // 텔레그램으로 연결돼 있으면 휴대폰 알림은 텔레그램이 보내므로 브라우저 알림은 생략
    final viaTelegram = context.read<TelegramLink>().linked;
    if (isPageHidden() && !viaTelegram) {
      for (final r in due) {
        showBrowserNotification('🔔 ${r.title}', r.body, r.key);
      }
    }
    _autoHide?.cancel();
    _autoHide = Timer(const Duration(seconds: 10), _close);
    setState(() => _showing = due);
  }

  void _close() {
    if (mounted) setState(() => _showing = const []);
  }

  @override
  Widget build(BuildContext context) {
    final visible = _showing.isNotEmpty;
    return Stack(
      children: [
        widget.child,
        SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: AnimatedSlide(
                offset: visible ? Offset.zero : const Offset(0, -1.5),
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                child: visible
                    ? ReminderBanner(
                        reminder: _showing.first,
                        moreCount: _showing.length - 1,
                        onClose: _close,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
