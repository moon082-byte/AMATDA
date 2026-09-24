import 'package:flutter/material.dart';

/// 토스(Toss) 스타일 디자인 시스템의 컬러 팔레트 (라이트/다크 모두 지원)
@immutable
class AppPalette extends ThemeExtension<AppPalette> {
  final Color background;
  final Color card;
  final Color fill;
  final Color border;
  final Color titleText;
  final Color bodyText;
  final Color subText;
  final Color accent;
  final Color accentSoft;
  final Color checkboxIdle;
  final Color danger;
  final Color dangerSoft;
  final Color success;
  final Color successSoft;
  final Color warning;
  final Color warningSoft;
  final Color shadow;

  const AppPalette({
    required this.background,
    required this.card,
    required this.fill,
    required this.border,
    required this.titleText,
    required this.bodyText,
    required this.subText,
    required this.accent,
    required this.accentSoft,
    required this.checkboxIdle,
    required this.danger,
    required this.dangerSoft,
    required this.success,
    required this.successSoft,
    required this.warning,
    required this.warningSoft,
    required this.shadow,
  });

  static const light = AppPalette(
    background: Color(0xFFF2F4F6),
    card: Colors.white,
    fill: Color(0xFFF2F4F6),
    border: Color(0xFFE5E8EB),
    titleText: Color(0xFF191F28),
    bodyText: Color(0xFF4E5968),
    subText: Color(0xFF8B95A1),
    accent: Color(0xFF3182F6),
    accentSoft: Color(0xFFE8F3FF),
    checkboxIdle: Color(0xFFD1D6DB),
    danger: Color(0xFFF04452),
    dangerSoft: Color(0xFFFFEEF0),
    success: Color(0xFF15B371),
    successSoft: Color(0xFFE5F8EF),
    warning: Color(0xFFFE9800),
    warningSoft: Color(0xFFFFF4E0),
    shadow: Color(0x0F1B2A3D),
  );

  static const dark = AppPalette(
    background: Color(0xFF17171C),
    card: Color(0xFF212128),
    fill: Color(0xFF2C2C35),
    border: Color(0xFF2E2E37),
    titleText: Color(0xFFF2F4F6),
    bodyText: Color(0xFFC3CAD2),
    subText: Color(0xFF8B95A1),
    accent: Color(0xFF5C9CFF),
    accentSoft: Color(0xFF1C2A40),
    checkboxIdle: Color(0xFF454A52),
    danger: Color(0xFFFF6B75),
    dangerSoft: Color(0xFF3A2027),
    success: Color(0xFF3DD68C),
    successSoft: Color(0xFF17332A),
    warning: Color(0xFFFFB547),
    warningSoft: Color(0xFF3A2D17),
    shadow: Color(0x00000000),
  );

  static const double cardRadius = 22.0;
  static const double fieldRadius = 14.0;
  static const double chipRadius = 999.0;

  @override
  AppPalette copyWith({Color? accent, Color? accentSoft}) {
    return AppPalette(
      background: background,
      card: card,
      fill: fill,
      border: border,
      titleText: titleText,
      bodyText: bodyText,
      subText: subText,
      accent: accent ?? this.accent,
      accentSoft: accentSoft ?? this.accentSoft,
      checkboxIdle: checkboxIdle,
      danger: danger,
      dangerSoft: dangerSoft,
      success: success,
      successSoft: successSoft,
      warning: warning,
      warningSoft: warningSoft,
      shadow: shadow,
    );
  }

  @override
  AppPalette lerp(ThemeExtension<AppPalette>? other, double t) {
    if (other is! AppPalette) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppPalette(
      background: c(background, other.background),
      card: c(card, other.card),
      fill: c(fill, other.fill),
      border: c(border, other.border),
      titleText: c(titleText, other.titleText),
      bodyText: c(bodyText, other.bodyText),
      subText: c(subText, other.subText),
      accent: c(accent, other.accent),
      accentSoft: c(accentSoft, other.accentSoft),
      checkboxIdle: c(checkboxIdle, other.checkboxIdle),
      danger: c(danger, other.danger),
      dangerSoft: c(dangerSoft, other.dangerSoft),
      success: c(success, other.success),
      successSoft: c(successSoft, other.successSoft),
      warning: c(warning, other.warning),
      warningSoft: c(warningSoft, other.warningSoft),
      shadow: c(shadow, other.shadow),
    );
  }
}

/// `context.palette`로 현재 테마의 팔레트에 접근하기 위한 확장
extension AppPaletteContext on BuildContext {
  AppPalette get palette =>
      Theme.of(this).extension<AppPalette>() ?? AppPalette.light;
}
