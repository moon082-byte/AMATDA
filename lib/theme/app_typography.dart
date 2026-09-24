import 'package:flutter/material.dart';
import 'app_palette.dart';

/// 한글 글꼴 대체 순서. 번들 폰트(Pretendard)가 없으면 OS 기본 한글 글꼴을 쓴다.
/// 테마 전체에 한 번만 지정하고, 아래 스타일들은 글꼴을 비워 두어 테마 설정을 물려받게 한다.
const kFontFallback = [
  'Pretendard',
  'Apple SD Gothic Neo',
  'Malgun Gothic',
  'Noto Sans KR',
];

/// 앱 전체에서 쓰는 텍스트 스타일 스케일. 한글 가독성을 위해 자간을 살짝 좁힌다.
class AppTypography {
  final AppPalette p;

  const AppTypography(this.p);

  /// 큰 숫자, 히어로 영역
  TextStyle get display => TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.8,
        height: 1.25,
        color: p.titleText,
      );

  /// 화면 제목
  TextStyle get h1 => TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.6,
        height: 1.3,
        color: p.titleText,
      );

  /// 바텀시트 제목, 큰 카드 제목
  TextStyle get h2 => TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
        height: 1.35,
        color: p.titleText,
      );

  /// 카드/리스트 항목 제목
  TextStyle get title => TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.3,
        height: 1.4,
        color: p.titleText,
      );

  /// 일반 본문
  TextStyle get body => TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.2,
        height: 1.45,
        color: p.bodyText,
      );

  /// 섹션 라벨, 필드 라벨
  TextStyle get label => TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
        color: p.subText,
      );

  /// 보조 설명, 메타 정보
  TextStyle get caption => TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        letterSpacing: -0.1,
        height: 1.4,
        color: p.subText,
      );

  /// 칩, 배지
  TextStyle get micro => TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.1,
        color: p.subText,
      );
}

/// `context.text.h1`처럼 현재 테마의 타이포그래피에 접근하기 위한 확장
extension AppTypographyContext on BuildContext {
  AppTypography get text => AppTypography(palette);
}
