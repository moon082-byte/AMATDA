import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/room_provider.dart';
import '../providers/routine_provider.dart';
import 'confirm_dialog.dart';

/// 확인을 받고 업무방을 삭제한다. 방의 할 일은 함께 지우고, 연결된 루틴은 남긴 채 연결만 푼다.
/// 삭제했으면 true를 돌려준다.
Future<bool> confirmDeleteRoom(
    BuildContext context, String roomId, String name) async {
  final hasRoutines =
      context.read<RoutineProvider>().routinesForRoom(roomId).isNotEmpty;
  final confirmed = await confirmDelete(
    context,
    '"$name" 방을 삭제하면 방에 속한 할 일도 함께 삭제돼요.'
    '${hasRoutines ? ' 연결된 루틴은 남고 업무방 연결만 해제돼요.' : ''}',
  );
  if (!context.mounted || !confirmed) return false;
  context.read<RoutineProvider>().unlinkRoom(roomId);
  context.read<RoomProvider>().deleteRoom(roomId);
  return true;
}
