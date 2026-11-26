import 'package:flutter/material.dart';
import '../services/app_update.dart';
import '../services/inbox_service.dart';
import '../services/notion_service.dart';
import '../services/sync_service.dart';
import '../services/telegram_link.dart';
import 'maybe_provider.dart';

/// 🔄 새로고침·당겨서 새로고침: 서버에서 할 일·루틴·메모, 알림함, 텔레그램·노션 연결 상태를 다시 받고
/// 새 버전이 배포됐는지도 확인한다. 동기화하지 못했으면 이유를 알림줄로 보여준다.
Future<void> refreshAll(BuildContext context) async {
  final sync = maybeProvider<SyncService>(context, listen: false);
  final messenger = ScaffoldMessenger.of(context);
  await Future.wait([
    if (sync != null) sync.syncNow(),
    if (maybeProvider<InboxService>(context, listen: false) case final inbox?) inbox.refresh(),
    if (maybeProvider<TelegramLink>(context, listen: false) case final link? when link.available) link.refresh(),
    if (maybeProvider<NotionService>(context, listen: false) case final notion?) notion.refresh(),
    if (maybeProvider<AppUpdate>(context, listen: false) case final update?) update.check(),
  ]);
  final error = sync?.error;
  if (error != null) {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('새로 받지 못했어요: $error')));
  }
}
