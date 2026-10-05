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

extension ReminderOptionOffset on ReminderOption {
  /// 마감 몇 분/시간/일 전에 알릴지 (알림 없음이면 null)
  Duration? get offset => switch (this) {
        ReminderOption.none => null,
        ReminderOption.tenMinutesBefore => const Duration(minutes: 10),
        ReminderOption.thirtyMinutesBefore => const Duration(minutes: 30),
        ReminderOption.oneHourBefore => const Duration(hours: 1),
        ReminderOption.oneDayBefore => const Duration(days: 1),
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
  final ReminderOption reminderOption;

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
    this.reminderOption = ReminderOption.none,
    this.workLinks = const [],
  });

  /// 마감 리마인드가 울릴 시각 (마감이나 알림 설정이 없으면 null)
  DateTime? get reminderAt {
    final due = dueDate;
    final offset = reminderOption.offset;
    return due == null || offset == null ? null : due.subtract(offset);
  }

  /// 업무방 수정 화면에서 바꿀 수 있는 항목만 교체한다
  TelegramRoom copyWithEdits({
    required String name,
    required String inviteLink,
    required List<String> workLinks,
    DateTime? dueDate,
    required ReminderOption reminderOption,
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
      reminderOption: reminderOption,
      workLinks: workLinks,
    );
  }
}
