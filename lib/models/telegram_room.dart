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

/// 화면 UI 개발용 가짜(Mock) 텔레그램 방 데이터
final List<TelegramRoom> mockTelegramRooms = [
  TelegramRoom(
    id: 'room_001',
    name: '팀 프로젝트 - 아맞다',
    type: TelegramRoomType.group,
    inviteLink: 'https://t.me/joinchat/amatda_team',
    memberCount: 5,
    isPinned: true,
    unreadCount: 3,
    lastActivityAt: DateTime(2026, 9, 20, 14, 30),
    dueDate: DateTime(2026, 9, 25, 18, 0),
    reminderOption: ReminderOption.oneDayBefore,
  ),
  TelegramRoom(
    id: 'room_002',
    name: '김철수',
    type: TelegramRoomType.private,
    inviteLink: 'https://t.me/kim_chulsoo',
    memberCount: 2,
    lastActivityAt: DateTime(2026, 9, 19, 9, 15),
  ),
  TelegramRoom(
    id: 'room_003',
    name: '공지사항 채널',
    type: TelegramRoomType.channel,
    inviteLink: 'https://t.me/amatda_notice',
    memberCount: 128,
    unreadCount: 12,
    lastActivityAt: DateTime(2026, 9, 20, 8, 0),
    dueDate: DateTime(2026, 9, 30, 12, 0),
    reminderOption: ReminderOption.oneHourBefore,
  ),
];
