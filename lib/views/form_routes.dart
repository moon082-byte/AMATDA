import 'package:flutter/material.dart';
import '../models/routine.dart';
import '../models/task_item.dart';
import '../models/telegram_room.dart';
import 'room_form_page.dart';
import 'routine_composer.dart';
import 'task_composer.dart';

/// 입력 화면은 아래에서 올라오는 전체 화면으로 연다 (모바일 키보드에 가리지 않게)
Future<void> _open(BuildContext context, Widget page) => Navigator.push(
      context,
      MaterialPageRoute(fullscreenDialog: true, builder: (_) => page),
    );

/// 할 일·루틴 입력 블록은 아래에서 올라오는 시트로 연다 (키보드 바로 위에 붙는다)
Future<void> _sheet(BuildContext context, Widget block) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => block,
    );

/// 새 할 일 입력 블록을 연다. [roomId]가 없으면 업무방을 고르는 칸이 나온다.
Future<void> openAddTask(BuildContext context, [String? roomId]) =>
    _sheet(context, TaskComposer(roomId: roomId));

/// 기존 할 일의 제목/마감기한/리마인드를 수정하는 입력 블록을 연다
Future<void> openEditTask(BuildContext context, TaskItem task) =>
    _sheet(context, TaskComposer(task: task));

/// 새 업무방 만들기 화면을 연다
Future<void> openCreateRoom(BuildContext context) =>
    _open(context, const RoomFormPage());

/// 기존 업무방 수정 화면을 연다
Future<void> openEditRoom(BuildContext context, TelegramRoom room) =>
    _open(context, RoomFormPage(room: room));

/// 새 루틴 입력 블록을 연다
Future<void> openAddRoutine(BuildContext context) =>
    _sheet(context, const RoutineComposer());

/// 기존 루틴 수정 입력 블록을 연다
Future<void> openEditRoutine(BuildContext context, Routine routine) =>
    _sheet(context, RoutineComposer(routine: routine));
