/// 프로젝트 목록 화면 데이터 (/api/project-rooms?page=N 응답)
library;

/// 목록의 방 한 줄
class ProjectRoomSummary {
  final String id;
  final String name;
  final String goal;
  final bool isLeader;
  final int members;
  final int total;
  final int done;

  /// 나에게 배정된 미완료 업무 수
  final int myOpen;

  const ProjectRoomSummary({
    required this.id,
    required this.name,
    this.goal = '',
    this.isLeader = false,
    this.members = 1,
    this.total = 0,
    this.done = 0,
    this.myOpen = 0,
  });

  double get progress => total == 0 ? 0 : done / total;

  factory ProjectRoomSummary.fromJson(Map<String, dynamic> j) =>
      ProjectRoomSummary(
        id: j['id'] as String,
        name: j['name'] as String,
        goal: j['goal'] as String? ?? '',
        isLeader: j['role'] == 'leader',
        members: (j['members'] as num?)?.toInt() ?? 1,
        total: (j['total'] as num?)?.toInt() ?? 0,
        done: (j['done'] as num?)?.toInt() ?? 0,
        myOpen: (j['myOpen'] as num?)?.toInt() ?? 0,
      );
}

/// 받은 초대
typedef ProjectInvite = ({String roomId, String roomName, String invitedBy});

/// 방 목록 한 페이지 (10개씩)
class ProjectRoomPage {
  final int page;
  final int pageSize;
  final int total;
  final List<ProjectRoomSummary> rooms;
  final List<ProjectInvite> invites;

  const ProjectRoomPage({
    this.page = 1,
    this.pageSize = 10,
    this.total = 0,
    this.rooms = const [],
    this.invites = const [],
  });

  int get pageCount => total == 0 ? 1 : (total + pageSize - 1) ~/ pageSize;

  factory ProjectRoomPage.fromJson(Map<String, dynamic> j) => ProjectRoomPage(
        page: (j['page'] as num?)?.toInt() ?? 1,
        pageSize: (j['pageSize'] as num?)?.toInt() ?? 10,
        total: (j['total'] as num?)?.toInt() ?? 0,
        rooms: [
          for (final r in j['rooms'] as List? ?? const [])
            ProjectRoomSummary.fromJson(r as Map<String, dynamic>),
        ],
        invites: [
          for (final i in j['invites'] as List? ?? const [])
            (
              roomId: i['roomId'] as String,
              roomName: i['roomName'] as String,
              invitedBy: i['invitedBy'] as String? ?? '',
            ),
        ],
      );
}
