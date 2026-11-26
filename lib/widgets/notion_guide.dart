import 'package:flutter/material.dart';
import '../theme/app_palette.dart';
import '../theme/app_typography.dart';
import 'common/app_card.dart';

/// 노션 연동 방법 안내 (특정 데이터베이스 이름에 묶이지 않는다)
class NotionGuide extends StatelessWidget {
  const NotionGuide({super.key});

  static const steps = [
    ('노션 통합 만들기', 'notion.so/my-integrations → [새 통합] → 유형은 "내부" → 만들고 "내부 통합 시크릿"을 복사해요'),
    ('토큰 넣기', '복사한 시크릿(ntn_…)을 아래 "통합 토큰" 칸에 붙여 넣어요'),
    ('데이터베이스에 통합 연결', '연결할 노션 데이터베이스를 열고 오른쪽 위 ⋯ → [연결]에서 방금 만든 통합을 추가해요'),
    ('링크 붙여 넣고 매핑', '데이터베이스 링크를 붙여 넣고 [속성 불러오기] → 제목·완료·날짜·내용으로 쓸 속성을 고른 뒤 [저장]해요'),
  ];

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final text = context.text;
    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('연동 방법', style: text.title),
          const SizedBox(height: 10),
          for (final (i, (title, body)) in steps.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CircleAvatar(
                    radius: 11,
                    backgroundColor: palette.accentSoft,
                    child: Text('${i + 1}', style: text.micro.copyWith(color: palette.accent)),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.body.copyWith(color: palette.titleText)),
                        Text(body, style: text.caption),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
