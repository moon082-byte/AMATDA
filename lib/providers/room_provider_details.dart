part of 'room_provider.dart';

/// 할 일 안의 세부 체크리스트와 업무 메모 편집
extension RoomTaskDetails on RoomProvider {
  void addSubTask(String taskId, SubTask subTask) =>
      _edit(taskId, (t) => t.copyWith(subTasks: [...t.subTasks, subTask]));

  void toggleSubTask(String taskId, String subTaskId) => _edit(
        taskId,
        (t) => t.copyWith(subTasks: [
          for (final s in t.subTasks)
            s.id == subTaskId ? s.copyWith(isDone: !s.isDone) : s,
        ]),
      );

  void renameSubTask(String taskId, String subTaskId, String title) => _edit(
        taskId,
        (t) => t.copyWith(subTasks: [
          for (final s in t.subTasks)
            s.id == subTaskId ? s.copyWith(title: title) : s,
        ]),
      );

  /// 세부 항목을 지우고, 되돌릴 때 쓸 원래 위치를 돌려준다 (없으면 -1)
  int deleteSubTask(String taskId, String subTaskId) {
    final index = taskById(taskId)?.subTasks.indexWhere((s) => s.id == subTaskId) ?? -1;
    if (index == -1) return -1;
    _edit(taskId, (t) => t.copyWith(subTasks: [...t.subTasks]..removeAt(index)));
    return index;
  }

  void insertSubTask(String taskId, SubTask subTask, int index) => _edit(
        taskId,
        (t) => t.subTasks.any((s) => s.id == subTask.id)
            ? t
            : t.copyWith(
                subTasks: [...t.subTasks]
                  ..insert(index.clamp(0, t.subTasks.length), subTask),
              ),
      );

  void addNote(String taskId, Note note) =>
      _edit(taskId, (t) => t.copyWith(notes: [...t.notes, note]));

  void updateNote(String taskId, String noteId, String content) => _edit(
        taskId,
        (t) => t.copyWith(notes: [
          for (final n in t.notes)
            n.id == noteId ? n.copyWith(content: content) : n,
        ]),
      );

  void deleteNote(String taskId, String noteId) => _edit(
        taskId,
        (t) => t.copyWith(notes: [
          for (final n in t.notes)
            if (n.id != noteId) n,
        ]),
      );
}
