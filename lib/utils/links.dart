import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

/// 입력한 링크를 열 수 있는 주소로 다듬는다. 스킴이 없으면 https://를 붙인다.
/// 비어 있으면 빈 문자열을 돌려준다.
String normalizeUrl(String input) {
  final value = input.trim();
  if (value.isEmpty) return '';
  final hasScheme = RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*:').hasMatch(value);
  return hasScheme ? value : 'https://$value';
}

/// 입력한 링크들을 다듬고 빈 칸은 뺀다
List<String> cleanLinks(Iterable<String> inputs) =>
    [for (final i in inputs.map(normalizeUrl)) if (i.isNotEmpty) i];

/// 링크 주소의 도메인 (예: notion.so). 해석할 수 없으면 원문을 돌려준다.
String linkHost(String url) {
  final host = Uri.tryParse(url)?.host ?? '';
  return host.isEmpty ? url : host.replaceFirst(RegExp(r'^www\.'), '');
}

/// 도메인으로 알아본 서비스 이름과 아이콘 (모르는 곳이면 '웹 링크')
(String, IconData) linkService(String url) {
  final host = linkHost(url).toLowerCase();
  bool has(List<String> keys) => keys.any(host.contains);
  if (has(['t.me', 'telegram'])) return ('텔레그램', Icons.send_rounded);
  if (has(['kakao'])) return ('카카오톡', Icons.chat_bubble_rounded);
  if (has(['notion'])) return ('노션', Icons.article_rounded);
  if (has(['blog', 'tistory', 'velog', 'brunch'])) {
    return ('블로그', Icons.edit_note_rounded);
  }
  if (has(['docs.google', 'drive.google'])) {
    return ('구글 문서', Icons.description_rounded);
  }
  if (has(['figma'])) return ('피그마', Icons.design_services_rounded);
  if (has(['github'])) return ('깃허브', Icons.code_rounded);
  if (has(['slack'])) return ('슬랙', Icons.forum_rounded);
  return ('웹 링크', Icons.link_rounded);
}

/// 링크를 외부 앱(없으면 새 브라우저 탭)으로 연다. 실패하면 안내 메시지를 띄운다.
Future<void> openExternalLink(BuildContext context, String link) async {
  final messenger = ScaffoldMessenger.of(context);
  final uri = Uri.tryParse(normalizeUrl(link));
  var ok = false;
  if (uri != null && uri.host.isNotEmpty) {
    try {
      ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      ok = false;
    }
  }
  if (!ok) {
    messenger.showSnackBar(const SnackBar(content: Text('링크를 열 수 없어요')));
  }
}
