import '../models/note.dart';
import '../models/routine.dart';
import '../models/sub_task.dart';
import '../models/task_item.dart';
import '../models/task_reminder.dart';
import '../models/telegram_room.dart';

/// 오늘 기준 [days]일 뒤의 [hour]:[minute] 시각
DateTime _at(int days, [int hour = 0, int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + days, hour, minute);
}

/// 처음 실행하거나 초기화했을 때 보여줄 샘플 업무방
List<TelegramRoom> buildMockTelegramRooms() => [
      TelegramRoom(
        id: 'room_001',
        name: '팀 프로젝트 - 아맞다',
        type: TelegramRoomType.group,
        inviteLink: 'https://t.me/joinchat/amatda_team',
        memberCount: 5,
        isPinned: true,
        unreadCount: 3,
        lastActivityAt: _at(0, 9, 30),
        dueDate: _at(3, 18),
        reminders: const [TaskReminder(amount: 1, unit: ReminderUnit.day)],
        workLinks: const [
          'https://www.notion.so/amatda-team',
          'https://open.kakao.com/o/amatda',
        ],
      ),
      TelegramRoom(
        id: 'room_002',
        name: '김철수',
        type: TelegramRoomType.private,
        inviteLink: 'https://t.me/kim_chulsoo',
        memberCount: 2,
        lastActivityAt: _at(-1, 9, 15),
      ),
      TelegramRoom(
        id: 'room_003',
        name: '공지사항 채널',
        type: TelegramRoomType.channel,
        inviteLink: 'https://t.me/amatda_notice',
        memberCount: 128,
        unreadCount: 12,
        lastActivityAt: _at(0, 8),
        dueDate: _at(10, 12),
        reminders: const [TaskReminder(amount: 1, unit: ReminderUnit.hour)],
      ),
    ];

/// 처음 실행하거나 초기화했을 때 보여줄 샘플 할 일
List<TaskItem> buildMockTaskItems() => [
      TaskItem(
        id: 'task_001',
        title: '주간 보고서 작성',
        description: '팀장님께 전달할 주간 업무 보고서 작성',
        dueDate: _at(2, 18),
        reminders: const [
          TaskReminder(amount: 1, unit: ReminderUnit.day),
          TaskReminder(amount: 1, unit: ReminderUnit.hour),
        ],
        priority: TaskPriority.high,
        roomId: 'room_001',
        createdAt: _at(-2, 10),
        subTasks: const [
          SubTask(id: 'sub_001', title: '지난주 데이터 정리', isDone: true),
          SubTask(id: 'sub_002', title: '보고서 초안 작성'),
          SubTask(id: 'sub_003', title: '팀장 검토 요청'),
        ],
        notes: [
          Note(
            id: 'note_001',
            content: '금요일 오전까지 초안 공유하기',
            createdAt: _at(-2, 11),
          ),
        ],
      ),
      TaskItem(
        id: 'task_002',
        title: '디자인 시안 확인',
        isDone: true,
        dueDate: _at(-1),
        completedAt: _at(-1, 14),
        roomId: 'room_001',
        createdAt: _at(-3, 13),
      ),
      TaskItem(
        id: 'task_003',
        title: '회의실 예약하기',
        description: '다음 주 화요일 오후 팀 회의용',
        dueDate: _at(0, 15),
        priority: TaskPriority.low,
        createdAt: _at(-1, 11, 30),
      ),
    ];

/// 처음 실행하거나 초기화했을 때 보여줄 샘플 루틴
/// (리마인드는 비워 둔다: 처음 열자마자 알림이 뜨지 않게)
List<Routine> buildMockRoutines() => [
      Routine(
        id: 'routine_001',
        name: '아침 업무 메일 확인',
        weekdays: weekDays,
        hour: 9,
        createdAt: _at(-7),
      ),
      Routine(
        id: 'routine_002',
        name: '물 한 잔 마시기',
        weekdays: everyDay,
        hour: 15,
        createdAt: _at(-7),
      ),
      Routine(
        id: 'routine_003',
        name: '주간 회고 쓰기',
        weekdays: const {DateTime.friday},
        hour: 17,
        minute: 30,
        createdAt: _at(-7),
      ),
    ];
