/// 프로젝트방 데이터 (서버 공유 데이터, /api/project-rooms 응답 모양 그대로)
/// 구조: 프로젝트방(이름·목표·텔레그램·팀원) → 프로젝트(마감) → 세부업무(담당자·마감·완료)
library;

DateTime? _ms(Object? v) =>
    v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;

class ProjectMember {
  final String userId;
  final String handle;
  final String nickname;
  final bool isLeader;

  /// 초대만 받고 아직 수락하지 않음
  final bool invited;

  const ProjectMember({
    required this.userId,
    required this.handle,
    this.nickname = '',
    this.isLeader = false,
    this.invited = false,
  });

  factory ProjectMember.fromJson(Map<String, dynamic> j) => ProjectMember(
        userId: j['userId'] as String,
        handle: j['handle'] as String? ?? '',
        nickname: j['nickname'] as String? ?? '',
        isLeader: j['role'] == 'leader',
        invited: j['status'] == 'invited',
      );
}

/// 세부업무 상태: 진행중 → (담당자 완료 보고) 검토중 → (팀장) 최종완료. 반려하면 진행중.
enum TaskStatus { open, review, done }

class ProjectTask {
  final String id;
  final String projectId;
  final String title;
  final String? assigneeId;
  final DateTime? dueAt;
  final DateTime? doneAt;

  /// 담당자가 완료 보고(검토 요청)한 시각
  final DateTime? reviewAt;

  const ProjectTask({
    required this.id,
    required this.projectId,
    required this.title,
    this.assigneeId,
    this.dueAt,
    this.doneAt,
    this.reviewAt,
  });

  /// 최종완료
  bool get isDone => doneAt != null;

  TaskStatus get status => isDone
      ? TaskStatus.done
      : reviewAt != null
          ? TaskStatus.review
          : TaskStatus.open;

  factory ProjectTask.fromJson(Map<String, dynamic> j) => ProjectTask(
        id: j['id'] as String,
        projectId: j['projectId'] as String? ?? '',
        title: j['title'] as String,
        assigneeId: j['assigneeId'] as String?,
        dueAt: _ms(j['dueAt']),
        doneAt: _ms(j['doneAt']),
        reviewAt: _ms(j['reviewAt']),
      );
}

class Project {
  final String id;
  final String name;
  final DateTime? dueAt;

  /// 팀장이 건 리마인더 시각 (팀장과 진행 중 업무 담당자에게 간다)
  final List<DateTime> remindAt;
  final List<ProjectTask> tasks;

  const Project({
    required this.id,
    required this.name,
    this.dueAt,
    this.remindAt = const [],
    this.tasks = const [],
  });

  int get doneCount => tasks.where((t) => t.isDone).length;
  double get progress => tasks.isEmpty ? 0 : doneCount / tasks.length;

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        name: j['name'] as String,
        dueAt: _ms(j['dueAt']),
        remindAt: [for (final t in j['remindAt'] as List? ?? const []) ?_ms(t)],
        tasks: [
          for (final t in j['tasks'] as List? ?? const [])
            ProjectTask.fromJson(t as Map<String, dynamic>),
        ],
      );
}
