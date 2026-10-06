import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../data/local_store.dart';
import '../providers/room_provider.dart';
import '../providers/routine_provider.dart';
import '../services/auth_service.dart';
import '../services/sync_service.dart';
import '../utils/maybe_provider.dart';

/// 로그인 도입 전 이 기기에 쌓인 데이터를 주인 계정으로 가져올지 묻는다 (기기마다 한 번).
/// 계정 데이터를 서버에서 먼저 받은 뒤 물어서, 같은 항목은 계정에 있는 것을 남긴다.
Future<void> offerLegacyImport(BuildContext context) async {
  final auth = maybeProvider<AuthService>(context, listen: false);
  final sync = maybeProvider<SyncService>(context, listen: false);
  final store = auth?.store;
  if (auth == null || sync == null || store == null) return;
  if (auth.user?.owner != true || store.legacyImportAsked) return;

  final rooms = store.loadRooms() ?? const [];
  final tasks = store.loadTasks() ?? const [];
  final routines = store.loadRoutines() ?? const [];
  if (rooms.isEmpty && tasks.isEmpty && routines.isEmpty) {
    await store.markLegacyImportAsked();
    return;
  }
  try {
    await sync.firstSync.timeout(const Duration(seconds: 20));
  } catch (_) {
    return; // 서버에 연결되지 않으면 다음에 다시 묻는다
  }
  if (!context.mounted) return;

  final ok = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('이 기기의 기존 데이터를 가져올까요?'),
      content: Text(
        '로그인 전에 이 기기에 저장된 데이터가 있어요.\n'
        '업무방 ${rooms.length}개 · 할 일 ${tasks.length}개 · 루틴 ${routines.length}개\n\n'
        '가져오면 ${auth.user!.email} 계정에 합쳐져 다른 기기에서도 보여요. '
        '계정에 이미 있는 항목은 계정 것을 그대로 둬요.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('안 함'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('가져오기'),
        ),
      ],
    ),
  );
  if (ok == null) return;
  await store.markLegacyImportAsked();
  if (!ok || !context.mounted) return;

  final added = context.read<RoomProvider>().mergeMissing(rooms, tasks) +
      context.read<RoutineProvider>().mergeMissing(routines);
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(added == 0 ? '모두 이미 계정에 있어요' : '$added개 항목을 계정으로 가져왔어요'),
  ));
}
