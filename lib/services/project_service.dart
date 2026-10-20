import '../models/project_room_page.dart';
import '../models/project_room.dart';
import 'api_client.dart';

/// 프로젝트방 서버 API. 방을 바꾸는 요청은 바뀐 방 상세를 돌려준다.
/// 권한(팀장·팀원)은 서버가 검사하고, 거절하면 [ApiException]의 message로 이유를 알려 준다.
class ProjectService {
  final ApiClient _api;

  ProjectService(this._api);

  Future<ProjectRoom> _room(Future<Map<String, dynamic>> res) async =>
      ProjectRoom.fromJson(await res);

  int? _ms(DateTime? d) => d?.millisecondsSinceEpoch;

  Map<String, Object?> _roomBody(String name, String goal, String telegramUrl) =>
      {'name': name, 'goal': goal, 'telegramUrl': telegramUrl};

  Map<String, Object?> _taskBody(String title, String? assigneeId, DateTime? dueAt) =>
      {'title': title, 'assigneeId': assigneeId, 'dueAt': _ms(dueAt)};

  Future<ProjectRoomPage> list({int page = 1}) async =>
      ProjectRoomPage.fromJson(await _api.get('/api/project-rooms?page=$page'));

  Future<ProjectRoom> detail(String id) =>
      _room(_api.get('/api/project-rooms/$id'));

  Future<ProjectRoom> create(
          {required String name, String goal = '', String telegramUrl = ''}) =>
      _room(_api.post('/api/project-rooms', _roomBody(name, goal, telegramUrl)));

  Future<ProjectRoom> update(String id,
          {required String name, String goal = '', String telegramUrl = ''}) =>
      _room(_api.put(
          '/api/project-rooms/$id', _roomBody(name, goal, telegramUrl)));

  Future<void> delete(String id) => _api.delete('/api/project-rooms/$id');

  /// 닉네임#태그로 사람 찾기
  Future<({String userId, String handle})> lookup(String handle) async {
    final res = await _api.get(
        '/api/users/lookup?handle=${Uri.encodeQueryComponent(handle.trim())}');
    return (userId: res['userId'] as String, handle: res['handle'] as String);
  }

  Future<ProjectRoom> invite(String roomId, String userId) => _room(
      _api.post('/api/project-rooms/$roomId/invites', {'userId': userId}));

  Future<ProjectRoom> accept(String roomId) =>
      _room(_api.post('/api/project-rooms/$roomId/accept'));

  Future<void> decline(String roomId) =>
      _api.post('/api/project-rooms/$roomId/decline');

  Future<ProjectRoom> removeMember(String roomId, String userId) =>
      _room(_api.delete('/api/project-rooms/$roomId/members/$userId'));

  Future<ProjectRoom> addProject(String roomId,
          {required String name, DateTime? dueAt}) =>
      _room(_api.post('/api/project-rooms/$roomId/projects',
          {'name': name, 'dueAt': _ms(dueAt)}));

  Future<ProjectRoom> updateProject(String id,
          {required String name, DateTime? dueAt}) =>
      _room(_api.put('/api/projects/$id', {'name': name, 'dueAt': _ms(dueAt)}));

  Future<ProjectRoom> deleteProject(String id) =>
      _room(_api.delete('/api/projects/$id'));

  Future<ProjectRoom> addTask(String projectId,
          {required String title, String? assigneeId, DateTime? dueAt}) =>
      _room(_api.post('/api/projects/$projectId/tasks',
          _taskBody(title, assigneeId, dueAt)));

  Future<ProjectRoom> updateTask(String id,
          {required String title, String? assigneeId, DateTime? dueAt}) =>
      _room(_api.put(
          '/api/project-tasks/$id', _taskBody(title, assigneeId, dueAt)));

  Future<ProjectRoom> deleteTask(String id) =>
      _room(_api.delete('/api/project-tasks/$id'));

  /// 내 업무 완료 보고 (팀장에게 알림이 간다)
  Future<ProjectRoom> complete(String id) =>
      _room(_api.post('/api/project-tasks/$id/complete'));
}
