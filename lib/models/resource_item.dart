/// 업무 문서/링크 자료의 종류
enum ResourceType { document, link, image, file }

/// 업무 문서/링크(자료)를 나타내는 모델
class ResourceItem {
  final String id;
  final String title;
  final String url;
  final ResourceType type;
  final String? description;
  final String? roomId;
  final DateTime addedAt;

  const ResourceItem({
    required this.id,
    required this.title,
    required this.url,
    required this.type,
    this.description,
    this.roomId,
    required this.addedAt,
  });
}

/// 화면 UI 개발용 가짜(Mock) 자료 데이터
final List<ResourceItem> mockResourceItems = [
  ResourceItem(
    id: 'res_001',
    title: '2026년 3분기 기획서.pdf',
    url: 'https://example.com/files/plan_2026_q3.pdf',
    type: ResourceType.document,
    roomId: 'room_001',
    addedAt: DateTime(2026, 9, 15, 9, 0),
  ),
  ResourceItem(
    id: 'res_002',
    title: '디자인 시스템 피그마',
    url: 'https://figma.com/file/example-design-system',
    type: ResourceType.link,
    description: '팀 공용 디자인 시스템 링크',
    roomId: 'room_001',
    addedAt: DateTime(2026, 9, 16, 15, 20),
  ),
  ResourceItem(
    id: 'res_003',
    title: '공지사항 안내 이미지',
    url: 'https://example.com/images/notice.png',
    type: ResourceType.image,
    roomId: 'room_003',
    addedAt: DateTime(2026, 9, 20, 8, 5),
  ),
];
