import 'package:flutter/material.dart';
import '../models/project.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';
import 'common/progress_bar.dart';
import 'task_row_actions.dart';

/// [팀원] 탭의 한 사람 카드: 진행률, [진행 중 N](기본 펼침)·[완료 N](기본 접힘) 토글
class ProjectMemberCard extends StatefulWidget {
  final String title;
  final Widget avatar;
  final String? badge;
  final List<ProjectTask> tasks;
  final TaskRowActions actions;

  const ProjectMemberCard({
    super.key,
    required this.title,
    required this.avatar,
    required this.tasks,
    required this.actions,
    this.badge,
  });

  @override
  State<ProjectMemberCard> createState() => ProjectMemberCardState();
}

class ProjectMemberCardState extends State<ProjectMemberCard> {
  bool _openShown = true;
  bool _doneShown = false;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    final open = [for (final t in widget.tasks) if (!t.isDone) t];
    final done = [for (final t in widget.tasks) if (t.isDone) t];

    Widget toggle(String label, int count, bool shown, VoidCallback onTap) => InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              Text('$label $count', style: text.label),
              Icon(shown ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 20, color: palette.subText),
            ]),
          ),
        );

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              widget.avatar,
              const SizedBox(width: 10),
              Expanded(child: Text(widget.title, style: text.title)),
              if (widget.badge case final b?)
                Text(b, style: text.caption.copyWith(color: palette.accent, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
            ]),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ProgressBar(
                  value: widget.tasks.isEmpty ? 0 : done.length / widget.tasks.length, height: 6),
            ),
            if (widget.tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('배정된 업무가 없어요', style: text.caption),
              )
            else ...[
              toggle('진행 중', open.length, _openShown, () => setState(() => _openShown = !_openShown)),
              if (_openShown) for (final t in open) widget.actions.row(t, withProject: true),
              toggle('완료', done.length, _doneShown, () => setState(() => _doneShown = !_doneShown)),
              if (_doneShown) for (final t in done) widget.actions.row(t, withProject: true),
            ],
          ],
        ),
      ),
    );
  }
}
