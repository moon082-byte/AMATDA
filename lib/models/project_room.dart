import 'project.dart';

/// 프로젝트방 상세: 방 정보, 내 역할, 팀원, 프로젝트·세부업무
class ProjectRoom {
  final String id;
  final String name;
  final String goal;
  final String telegramUrl;
  final String myId;
  final bool isLeader;

  /// 초대만 받고 아직 수락하지 않은 상태로 미리 보는 중
  final bool invited;
  final List<ProjectMember> members;
  final List<Project> projects;

  const ProjectRoom({
    required this.id,
    required this.name,
    this.goal = '',
    this.telegramUrl = '',
    required this.myId,
    this.isLeader = false,
    this.invited = false,
    this.members = const [],
    this.projects = const [],
  });

  /// 참여 중인 팀원 (초대 중 제외)
  List<ProjectMember> get activeMembers =>
      [for (final m in members) if (!m.invited) m];

  List<ProjectTask> get allTasks => [for (final p in projects) ...p.tasks];

  /// 나에게 배정된 미완료 업무 수 ("할 일 N개가 남아있어요")
  int get myOpenCount =>
      allTasks.where((t) => t.assigneeId == myId && !t.isDone).length;

  /// 세부업무가 속한 프로젝트
  Project projectOf(ProjectTask t) => projects.firstWhere((p) => p.id == t.projectId);

  /// [userId]에게 배정된 업무 (진행 중 먼저)
  List<ProjectTask> tasksOf(String? userId) => [
        for (final t in allTasks) if (t.assigneeId == userId && !t.isDone) t,
        for (final t in allTasks) if (t.assigneeId == userId && t.isDone) t,
      ];

  ProjectMember? memberById(String? id) =>
      members.where((m) => m.userId == id).firstOrNull;

  factory ProjectRoom.fromJson(Map<String, dynamic> j) {
    final room = j['room'] as Map<String, dynamic>;
    final me = j['me'] as Map<String, dynamic>;
    return ProjectRoom(
      id: room['id'] as String,
      name: room['name'] as String,
      goal: room['goal'] as String? ?? '',
      telegramUrl: room['telegramUrl'] as String? ?? '',
      myId: me['userId'] as String,
      isLeader: me['role'] == 'leader',
      invited: me['status'] == 'invited',
      members: [
        for (final m in j['members'] as List? ?? const [])
          ProjectMember.fromJson(m as Map<String, dynamic>),
      ],
      projects: [
        for (final p in j['projects'] as List? ?? const [])
          Project.fromJson(p as Map<String, dynamic>),
      ],
    );
  }
}
