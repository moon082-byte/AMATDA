import 'package:flutter/material.dart';
import '../theme/app_typography.dart';
import '../widgets/common/empty_state.dart';

/// [프로세스] 탭: 목표·리뷰를 작성하는 곳 (다음에 만든다)
class ProcessView extends StatelessWidget {
  const ProcessView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
          children: [
            Text('프로세스', style: context.text.h1),
            const SizedBox(height: 60),
            const EmptyState(
              icon: Icons.flag_rounded,
              title: '준비 중이에요',
              message: '목표를 세우고 리뷰를 작성하는 공간이 곧 생겨요',
            ),
          ],
        ),
      ),
    );
  }
}
