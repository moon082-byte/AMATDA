import 'package:flutter/material.dart';
import '../models/notion_settings.dart';
import '../services/notion_db_draft.dart';
import '../theme/app_typography.dart';

/// [속성 불러오기]로 읽은 속성 중에서 아맞다 칸마다 쓸 노션 속성을 드롭다운으로 고른다.
/// 할 일: 제목·완료(+완료 값·할 일 값)·날짜·내용 / 메모: 제목·날짜·내용·처음 상태(+값)
class NotionMapFields extends StatelessWidget {
  final NotionDbDraft draft;
  const NotionMapFields({super.key, required this.draft});

  @override
  Widget build(BuildContext context) {
    final db = draft.db!;
    final map = draft.map;
    final task = draft.target == NotionTarget.task;
    final done = db.byName(map.done);
    final status = db.byName(map.status);
    Widget prop(String label, List<String> types, String? value, void Function(NotionMap, String?) set,
            {bool optional = true}) =>
        _Pick(
          label: label,
          value: value,
          items: [for (final p in db.ofTypes(types)) p.name],
          optional: optional,
          onChanged: (v) => draft.edit((m) => set(m, v)),
        );
    Widget option(String label, NotionProperty p, String? value, void Function(NotionMap, String?) set) =>
        _Pick(label: label, value: value, items: p.options, onChanged: (v) => draft.edit((m) => set(m, v)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        prop('제목', const ['title'], map.title, (m, v) => m.title = v, optional: false),
        if (task) ...[
          prop('완료', const ['checkbox', 'select', 'status'], map.done, (m, v) {
            m.done = v;
            m.doneValue = m.todoValue = null;
          }),
          if (done != null && done.type != 'checkbox') ...[
            option('완료일 때 값', done, map.doneValue, (m, v) => m.doneValue = v),
            option('할 일일 때 값', done, map.todoValue, (m, v) => m.todoValue = v),
          ],
        ],
        prop(task ? '날짜 (마감)' : '날짜 (작성일)', const ['date'], map.date, (m, v) => m.date = v),
        prop('내용 (요약)', const ['rich_text'], map.content, (m, v) => m.content = v),
        if (!task) ...[
          prop('처음 상태', const ['select', 'status'], map.status, (m, v) {
            m.status = v;
            m.statusValue = null;
          }),
          if (status != null) option('처음 상태 값', status, map.statusValue, (m, v) => m.statusValue = v),
        ],
        Text(
          task ? '페이지 본문에는 설명, 세부 체크리스트, 메모를 넣어요' : '페이지 본문에는 메모 내용 전체를 넣어요',
          style: context.text.caption,
        ),
      ],
    );
  }
}

/// 라벨 + 드롭다운 한 줄 ([optional]이면 '보내지 않음'도 고를 수 있다)
class _Pick extends StatelessWidget {
  final String label;
  final String? value;
  final List<String> items;
  final bool optional;
  final ValueChanged<String?> onChanged;

  const _Pick({
    required this.label,
    required this.value,
    required this.items,
    this.optional = true,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String?>(
        key: ValueKey('$label:$value'),
        initialValue: items.contains(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        hint: Text(items.isEmpty ? '쓸 수 있는 속성이 없어요' : '보내지 않음'),
        items: [
          if (optional) const DropdownMenuItem<String?>(value: null, child: Text('보내지 않음')),
          for (final name in items) DropdownMenuItem<String?>(value: name, child: Text(name)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
