import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/profile_service.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import '../utils/maybe_provider.dart';

/// 닉네임 입력칸 검사 (서버 규칙과 같음). 문제없으면 null.
String? nicknameError(String value) {
  final v = value.trim();
  if (v.contains('#')) return '# 은 쓸 수 없어요 (태그는 자동으로 붙어요)';
  if (v.runes.length < 2 || v.runes.length > 12) return '2~12자로 정해 주세요';
  return null;
}

/// 처음 로그인했을 때 닉네임을 정하는 화면. 저장하면 닉네임#태그(4자리)가 만들어진다.
class NicknameSetupView extends StatefulWidget {
  const NicknameSetupView({super.key});

  @override
  State<NicknameSetupView> createState() => _NicknameSetupViewState();
}

class _NicknameSetupViewState extends State<NicknameSetupView> {
  // 구글 계정 이름을 처음 값으로 제안한다
  late final _name = TextEditingController(
    text: (maybeProvider<AuthService>(context, listen: false)?.user?.name ?? '')
        .trim()
        .characters
        .take(12)
        .toString(),
  );
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final error = nicknameError(_name.text);
    if (error != null) return setState(() => _error = error);
    final res = await context.read<ProfileService>().save(nickname: _name.text);
    if (!mounted) return;
    setState(() => _error = res.error);
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final busy = context.watch<ProfileService>().busy;

    return Scaffold(
      backgroundColor: palette.card,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
          children: [
            Text('반가워요!\n닉네임을 정해 주세요', style: text.h1),
            const SizedBox(height: 10),
            Text(
              '닉네임 뒤에는 겹치지 않도록 4자리 태그가 붙어요 (예: 아맞다#4821).\n나중에 설정에서 바꿀 수 있어요.',
              style: text.body.copyWith(color: palette.subText),
            ),
            const SizedBox(height: 28),
            TextField(
              controller: _name,
              autofocus: true,
              maxLength: 12,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              onChanged: (_) => setState(() => _error = null),
              decoration: InputDecoration(hintText: '닉네임', errorText: _error),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: busy ? null : _submit,
              child: Text(busy ? '저장하는 중…' : '시작하기'),
            ),
          ],
        ),
      ),
    );
  }
}
