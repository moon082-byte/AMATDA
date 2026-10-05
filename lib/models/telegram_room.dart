/// 텔레그램 방(채팅방)의 종류
enum TelegramRoomType { private, group, channel }

/// 업무방의 마감 기한 리마인더 알림 시점
enum ReminderOption {
  none,
  tenMinutesBefore,
  thirtyMinutesBefore,
  oneHourBefore,
  oneDayBefore,
}

extension ReminderOptionLabel on ReminderOption {
  String get label {
    switch (this) {
      case ReminderOption.none:
        return '알림 없음';
      case ReminderOption.tenMinutesBefore:
        return '10분 전';
      case ReminderOption.thirtyMinutesBefore:
        return '30분 전';
      case ReminderOption.oneHourBefore:
        return '1시간 전';
      case ReminderOption.oneDayBefore:
        return '1일 전';
    }
  }
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
  final ReminderOption reminderOption;

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
    this.reminderOption = ReminderOption.none,
  });
}
