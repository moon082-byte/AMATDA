import 'dart:convert';
import 'package:http/http.dart' as http;

/// 서버 요청 실패. [status]가 0이면 인터넷 연결 문제다.
class ApiException implements Exception {
  final int status;
  final String message;

  const ApiException(this.status, this.message);

  bool get isOffline => status == 0;
  bool get isUnauthorized => status == 401 || status == 403;

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
    final error = ApiException(
        res.statusCode, json['error'] as String? ?? '서버 오류 (${res.statusCode})');
    if (error.isUnauthorized && token != null) onUnauthorized?.call();
    throw error;
  }
}
