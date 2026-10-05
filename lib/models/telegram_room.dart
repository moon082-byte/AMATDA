import 'task_reminder.dart';

/// 텔레그램 방(채팅방)의 종류
enum TelegramRoomType { private, group, channel }

extension TelegramRoomTypeLabel on TelegramRoomType {
  String get label => switch (this) {
        TelegramRoomType.private => '개인',
        TelegramRoomType.group => '그룹',
        TelegramRoomType.channel => '채널',
      };
}

/// 텔레그램 방 정보를 나타내는 모델
class TelegramRoom {
  final String id;
  final String name;
  final TelegramRoomType type;
  final String inviteLink;
  final int memberCount;
  final String? profileImageUrl;
  final bool isPinned;
  final int unreadCount;
  final DateTime lastActivityAt;
  final DateTime? dueDate;

  /// 마감 리마인더 (최대 [TaskReminder.maxCount]개)
  final List<TaskReminder> reminders;

  /// 작업에 필요한 외부 링크 (카카오톡, 블로그, 노션 등)
  final List<String> workLinks;

  const TelegramRoom({
    required this.id,
    required this.name,
    required this.type,
    required this.inviteLink,
    this.memberCount = 1,
    this.profileImageUrl,
    this.isPinned = false,
    this.unreadCount = 0,
    required this.lastActivityAt,
    this.dueDate,
    this.reminders = const [],
    this.workLinks = const [],
  });

  /// 마감 리마인더가 울릴 시각들 (마감이 없으면 빈 목록)
  List<DateTime> get reminderTimes {
    final due = dueDate;
    return due == null ? const [] : [for (final r in reminders) r.fireAt(due)];
  }

  /// 업무방 수정 화면에서 바꿀 수 있는 항목만 교체한다
  TelegramRoom copyWithEdits({
    required String name,
    required TelegramRoomType type,
    required int memberCount,
    required String inviteLink,
    required List<String> workLinks,
    DateTime? dueDate,
    List<TaskReminder> reminders = const [],
  }) {
    return TelegramRoom(
      id: id,
      name: name,
      type: type,
      inviteLink: inviteLink,
      memberCount: memberCount,
      profileImageUrl: profileImageUrl,
      isPinned: isPinned,
      unreadCount: unreadCount,
      lastActivityAt: lastActivityAt,
      dueDate: dueDate,
      reminders: reminders,
      workLinks: workLinks,
    );
  }
}
