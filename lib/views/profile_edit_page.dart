import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/profile_service.dart';
import '../theme/app_palette.dart';
import '../utils/pick_avatar.dart';
import '../widgets/common/app_page.dart';
import '../widgets/field_label.dart';
import '../widgets/labeled_text_field.dart';
import '../widgets/profile_avatar.dart';
import 'nickname_setup_view.dart';

/// 프로필 편집: 사진 바꾸기·지우기(바로 저장), 닉네임·자기소개(저장 버튼). 닉네임을 바꿔도 태그는 유지된다.
class ProfileEditPage extends StatefulWidget {
  const ProfileEditPage({super.key});

  @override
  State<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends State<ProfileEditPage> {
  late final ProfileService _service = context.read<ProfileService>();
  late final _nickname = TextEditingController(text: _service.profile.nickname);
  late final _bio = TextEditingController(text: _service.profile.bio);

  @override
  void dispose() {
    _nickname.dispose();
    _bio.dispose();
    super.dispose();
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(message)));

  Future<void> _changePhoto() async {
    final picked = await pickAvatar();
    if (picked.error != null) return _toast(picked.error!);
    if (picked.jpeg == null) return;
    final error = await _service.setAvatar(picked.jpeg);
    if (mounted && error != null) _toast(error);
  }

  Future<void> _removePhoto() async {
    final error = await _service.setAvatar(null);
    if (mounted && error != null) _toast(error);
  }

  Future<void> _save() async {
    final error = nicknameError(_nickname.text);
    if (error != null) return _toast(error);
    final p = _service.profile;
    final nickname = _nickname.text.trim();
    final bio = _bio.text.trim();
    final res = await _service.save(
      nickname: nickname == p.nickname ? null : nickname,
      bio: bio == p.bio ? null : bio,
    );
    if (!mounted) return;
    if (res.error != null) return _toast(res.error!);
    if (res.notice != null) _toast(res.notice!);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final service = context.watch<ProfileService>();
    final profile = service.profile;

    return AppPage(
      title: '프로필 편집',
      closeIcon: true,
      actions: [saveAction(service.busy ? null : _save)],
      slivers: [
        paddedSliver(top: 8, [
          Center(child: ProfileAvatar(profile: profile, size: 96)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton.icon(
                onPressed: service.busy ? null : _changePhoto,
                icon: const Icon(Icons.photo_camera_rounded, size: 18),
                label: const Text('사진 변경'),
              ),
              if (profile.avatar != null)
                TextButton(
                  onPressed: service.busy ? null : _removePhoto,
                  style: TextButton.styleFrom(foregroundColor: palette.danger),
                  child: const Text('사진 삭제'),
                ),
            ],
          ),
          const SizedBox(height: 16),
          LabeledTextField(
            label: '닉네임 (태그 #${profile.tag} 는 그대로 유지돼요)',
            controller: _nickname,
            hint: '2~12자',
          ),
          const SizedBox(height: 24),
          const FieldLabel('자기소개'),
          TextField(
            controller: _bio,
            maxLength: 150,
            maxLines: 4,
            minLines: 2,
            scrollPadding: const EdgeInsets.only(bottom: 160),
            decoration: const InputDecoration(hintText: '나를 짧게 소개해 주세요'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: service.busy ? null : _save,
            child: const Text('저장하기'),
          ),
        ]),
      ],
    );
  }
}
