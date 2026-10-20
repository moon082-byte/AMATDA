import 'package:flutter/material.dart';
import '../models/profile.dart';
import '../theme/app_palette.dart';

/// 프로필 사진. 사진이 없으면 닉네임 첫 글자를 색 원 안에 보여준다 (닉네임마다 색이 다름).
class ProfileAvatar extends StatelessWidget {
  final Profile profile;
  final double size;

  const ProfileAvatar({super.key, required this.profile, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final bytes = profile.avatarBytes;
    if (bytes != null) {
      return ClipOval(
        child: Image.memory(
          bytes,
          width: size,
          height: size,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          semanticLabel: '프로필 사진',
        ),
      );
    }
    final name = profile.nickname.trim();
    final colors = [
      palette.accent,
      palette.routine,
      palette.success,
      palette.warning,
      palette.danger,
    ];
    final color = colors[name.runes.fold(0, (a, r) => a + r) % colors.length];
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        name.isEmpty ? '?' : String.fromCharCode(name.runes.first),
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.42,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
