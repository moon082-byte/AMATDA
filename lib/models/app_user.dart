/// 로그인한 사용자
class AppUser {
  final String id;
  final String email;
  final String name;
  final String picture;

  /// 주인 계정이면 로그인 도입 전 기기 데이터를 가져올 수 있다
  final bool owner;

  const AppUser({
    required this.id,
    required this.email,
    this.name = '',
    this.picture = '',
    this.owner = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as String,
        email: j['email'] as String,
        name: j['name'] as String? ?? '',
        picture: j['picture'] as String? ?? '',
        owner: j['owner'] == true,
      );

  Map<String, dynamic> toJson() =>
      {'id': id, 'email': email, 'name': name, 'picture': picture, 'owner': owner};
}
