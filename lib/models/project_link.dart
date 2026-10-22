/// 개인 할일이 프로젝트 세부업무에서 온 경우의 연결 정보 (서버가 배정할 때 넣는다).
/// 이런 할 일은 제목·마감을 바꿀 수 없고(잠금), 체크하면 프로젝트에 완료 보고가 된다.
class ProjectLink {
  final String roomId;
  final String roomName;
  final String projectName;

  /// 프로젝트 세부업무 id
  final String taskId;

  /// 검토중 (담당자가 완료 보고함). 담당자가 바꾸면 동기화로 서버에 보고·취소된다.
  final bool reviewRequested;

  const ProjectLink({
    required this.roomId,
    required this.roomName,
    required this.projectName,
    required this.taskId,
    this.reviewRequested = false,
  });

  ProjectLink withReview(bool on) => ProjectLink(
      roomId: roomId, roomName: roomName, projectName: projectName, taskId: taskId, reviewRequested: on);

  /// "신제품방 · 디자인"
  String get label => '$roomName방 · $projectName';

  static ProjectLink? fromJson(Object? j) {
    if (j is! Map) return null;
    final roomId = j['roomId'];
    final taskId = j['taskId'];
    if (roomId is! String || taskId is! String) return null;
    return ProjectLink(
      roomId: roomId,
      roomName: j['roomName'] as String? ?? '',
      projectName: j['projectName'] as String? ?? '',
      taskId: taskId,
      reviewRequested: j['reviewRequested'] == true,
    );
  }

  Map<String, Object> toJson() => {
        'roomId': roomId,
        'roomName': roomName,
        'projectName': projectName,
        'taskId': taskId,
        'reviewRequested': reviewRequested,
      };
}
