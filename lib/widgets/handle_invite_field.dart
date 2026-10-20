import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/project_service.dart';
import '../utils/confirm_action.dart';

/// 닉네임#태그를 입력해 사람을 찾는 칸. 찾으면 [onFound](userId, 닉네임#태그)를 부르고 칸을 비운다.
class HandleInviteField extends StatefulWidget {
  final void Function(String userId, String handle) onFound;

  const HandleInviteField({super.key, required this.onFound});

  @override
  State<HandleInviteField> createState() => _HandleInviteFieldState();
}

class _HandleInviteFieldState extends State<HandleInviteField> {
  final _controller = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final handle = _controller.text.trim();
    if (handle.isEmpty || _busy) return;
    setState(() => _busy = true);
    final found = await runWithMessage(
        context, () => context.read<ProjectService>().lookup(handle));
    if (!mounted) return;
    setState(() => _busy = false);
    if (found == null) return;
    _controller.clear();
    widget.onFound(found.userId, found.handle);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => _find(),
      scrollPadding: const EdgeInsets.only(bottom: 160),
      decoration: InputDecoration(
        hintText: '팀원 닉네임#태그 (예: 아맞다#1234)',
        suffixIcon: _busy
            ? const Padding(
                padding: EdgeInsets.all(14),
                child: SizedBox.square(
                    dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              )
            : IconButton(
                onPressed: _find,
                tooltip: '팀원 찾기',
                icon: const Icon(Icons.person_add_alt_1_rounded),
              ),
      ),
    );
  }
}
