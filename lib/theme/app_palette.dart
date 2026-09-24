import 'package:flutter/material.dart';

/// 토스(Toss) 스타일 디자인 시스템의 컬러 팔레트 (라이트/다크 모두 지원)
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color card;
  final Color titleText;
  final Color subText;
  final Color accent;
  final Color accentChipBackground;
  final Color checkboxIdle;

  const AppPalette({
    required this.background,
    required this.card,
    required this.titleText,
    required this.subText,
    required this.accent,
    required this.accentChipBackground,
    required this.checkboxIdle,
  });

  static const light = AppPalette(
    background: Color(0xFFF2F4F6),
    card: Colors.white,
    titleText: Color(0xFF191F28),
    subText: Color(0xFF8B95A1),
    accent: Color(0xFF3182F6),
    accentChipBackground: Color(0xFFE8F3FF),
    checkboxIdle: Color(0xFFD1D6DB),
  );

  static const dark = AppPalette(
    background: Color(0xFF121417),
    card: Color(0xFF1E2126),
    titleText: Color(0xFFF2F4F6),
    subText: Color(0xFF8B95A1),
    accent: Color(0xFF5C9CFF),
    accentChipBackground: Color(0xFF1E2B3D),
    checkboxIdle: Color(0xFF3A3F45),
  );

  static const double cardRadius = 20.0;
  static const double chipRadius = 999.0;

  @override
  AppPalette copyWith({
    Color? background,
    Color? card,
    Color? titleText,
    Color? subText,
    Color? accent,
    Color? accentChipBackground,
    Color? checkboxIdle,
  }) {
    return AppPalette(
      background: background ?? this.background,
      card: card ?? this.card,
      titleText: titleText ?? this.titleText,
      subText: subText ?? this.subText,
      accent: accent ?? this.accent,
      accentChipBackground: accentChipBackground ?? this.accentChipBackground,
      checkboxIdle: checkboxIdle ?? this.checkboxIdle,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    return AppPalette(
      background: Color.lerp(background, other.background, t)!,
      card: Color.lerp(card, other.card, t)!,
      titleText: Color.lerp(titleText, other.titleText, t)!,
      subText: Color.lerp(subText, other.subText, t)!,
      accent: Color.lerp(accent, other.accent, t)!,
      accentChipBackground:
          Color.lerp(accentChipBackground, other.accentChipBackground, t)!,
      checkboxIdle: Color.lerp(checkboxIdle, other.checkboxIdle, t)!,
    );
  }
}

/// `context.palette`로 현재 테마의 팔레트에 접근하기 위한 확장
extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
