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

class ProjectTask {
  final String id;
  final String projectId;
  final String title;
  final String? assigneeId;
  final DateTime? dueAt;
  final DateTime? doneAt;

  const ProjectTask({
    required this.id,
    required this.projectId,
    required this.title,
    this.assigneeId,
    this.dueAt,
    this.doneAt,
  });

  bool get isDone => doneAt != null;

  factory ProjectTask.fromJson(Map<String, dynamic> j) => ProjectTask(
        id: j['id'] as String,
        projectId: j['projectId'] as String? ?? '',
        title: j['title'] as String,
        assigneeId: j['assigneeId'] as String?,
        dueAt: _ms(j['dueAt']),
        doneAt: _ms(j['doneAt']),
      );
}

class Project {
  final String id;
  final String name;
  final DateTime? dueAt;
  final List<ProjectTask> tasks;

  const Project(
      {required this.id, required this.name, this.dueAt, this.tasks = const []});

  int get doneCount => tasks.where((t) => t.isDone).length;
  double get progress => tasks.isEmpty ? 0 : doneCount / tasks.length;

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        name: j['name'] as String,
        dueAt: _ms(j['dueAt']),
        tasks: [
          for (final t in j['tasks'] as List? ?? const [])
            ProjectTask.fromJson(t as Map<String, dynamic>),
        ],
      );
}
