import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/profile_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../widgets/common/app_page.dart';
import '../widgets/profile_avatar.dart';
import 'profile_edit_page.dart';

/// 내 프로필 화면: 사진, 닉네임#태그, 자기소개 + [프로필 편집]
class ProfileView extends StatelessWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final profile = context.watch<ProfileService>().profile;

    return AppPage(
      title: '프로필',
      slivers: [
        paddedSliver(top: 12, [
          Center(child: ProfileAvatar(profile: profile, size: 112)),
          const SizedBox(height: 18),
          Center(
            child: Text.rich(
              TextSpan(children: [
                TextSpan(text: profile.nickname, style: text.h1),
                if (profile.tag.isNotEmpty)
                  TextSpan(
                    text: ' #${profile.tag}',
                    style: text.h2.copyWith(color: palette.subText),
                  ),
              ]),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            profile.bio.isEmpty ? '아직 자기소개가 없어요' : profile.bio,
            textAlign: TextAlign.center,
            style: text.body.copyWith(
              color: profile.bio.isEmpty ? palette.subText : palette.bodyText,
            ),
          ),
          const SizedBox(height: 32),
          FilledButton.icon(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                fullscreenDialog: true,
                builder: (_) => const ProfileEditPage(),
              ),
            ),
            icon: const Icon(Icons.edit_rounded, size: 18),
            label: const Text('프로필 편집'),
          ),
        ]),
      ],
    );
  }
}
