import 'dart:convert';
import 'package:http/http.dart' as http;

/// 서버 요청 실패. [status]가 0이면 인터넷 연결 문제다.
class ApiException implements Exception {
  final int status;
  final String message;

  /// 서버가 함께 보낸 값 (예: PIN 남은 횟수 remaining, 잠금 해제 시각 lockedUntil)
  final Map<String, dynamic> data;

  const ApiException(this.status, this.message, [this.data = const {}]);

  bool get isOffline => status == 0;
  bool get isUnauthorized => status == 401 || status == 403;

  /// PIN을 켠 계정인데 이 로그인에서 아직 PIN을 확인하지 않았다
  bool get isPinRequired => status == 423 && data['pinRequired'] == true;

  @override
  String toString() => 'ApiException($status, $message)';
}

/// 아맞다 서버(봇 서버) 호출. 로그인돼 있으면 토큰을 붙인다.
class ApiClient {
  final http.Client _client;
  final String baseUrl;
  final String? Function() _token;

  /// 로그인이 만료되거나 계정이 막혔을 때 (401/403)
  void Function()? onUnauthorized;

  /// 다른 기기에서 PIN을 켜거나 바꿔서 이 기기도 PIN을 다시 입력해야 할 때 (423)
  void Function()? onPinRequired;

  ApiClient({
    required this.baseUrl,
    required this._token,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<Map<String, dynamic>> get(String path) => send('GET', path);
  Future<Map<String, dynamic>> post(String path, [Object? body]) =>
      send('POST', path, body);
  Future<Map<String, dynamic>> put(String path, Object body) =>
      send('PUT', path, body);
  Future<Map<String, dynamic>> delete(String path) => send('DELETE', path);

  Future<Map<String, dynamic>> send(String method, String path,
      [Object? body]) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'));
    final token = _token();
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _client.send(request));
    } catch (_) {
      throw const ApiException(0, '인터넷 연결을 확인해 주세요');
    }
    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      json = const {};
    }
    if (res.statusCode >= 200 && res.statusCode < 300) return json;
    final error = ApiException(res.statusCode,
        json['error'] as String? ?? '서버 오류 (${res.statusCode})', json);
    if (error.isUnauthorized && token != null) onUnauthorized?.call();
    if (error.isPinRequired) onPinRequired?.call();
    throw error;
  }
}
