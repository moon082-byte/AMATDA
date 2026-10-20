import 'dart:convert';
import 'dart:typed_data';

/// 내 프로필: 닉네임#태그, 프로필 사진, 자기소개
class Profile {
  final String nickname;

  /// 닉네임 뒤 4자리 고유 번호 (서버가 정한다)
  final String tag;
  final String bio;

  /// 프로필 사진 (data:image/jpeg;base64,...). 없으면 null → 닉네임 첫 글자 아바타
  final String? avatar;

  const Profile({
    this.nickname = '',
    this.tag = '',
    this.bio = '',
    this.avatar,
  });

  bool get hasNickname => nickname.isNotEmpty;

  /// "문다니엘#4821"
  String get handle => tag.isEmpty ? nickname : '$nickname#$tag';

  /// 사진 바이트 (없거나 읽을 수 없으면 null)
  Uint8List? get avatarBytes {
    final a = avatar;
    if (a == null) return null;
    try {
      return UriData.parse(a).contentAsBytes();
    } catch (_) {
      return null;
    }
  }

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        nickname: j['nickname'] as String? ?? '',
        tag: j['tag'] as String? ?? '',
        bio: j['bio'] as String? ?? '',
        avatar: j['avatar'] as String?,
      );

  Map<String, Object?> toJson() =>
      {'nickname': nickname, 'tag': tag, 'bio': bio, 'avatar': avatar};

  /// JPEG 바이트를 서버에 보낼 data URL로
  static String avatarDataUrl(Uint8List jpeg) =>
      'data:image/jpeg;base64,${base64Encode(jpeg)}';
}
