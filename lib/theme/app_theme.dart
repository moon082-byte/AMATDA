import 'package:flutter/material.dart';
import 'app_palette.dart';

/// 라이트/다크 모드 각각의 [ThemeData] 정의
class AppTheme {
  AppTheme._();

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppPalette.light.background,
    colorScheme: ColorScheme.fromSeed(seedColor: AppPalette.light.accent),
    extensions: const [AppPalette.light],
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppPalette.dark.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppPalette.dark.accent,
      brightness: Brightness.dark,
    ),
    extensions: const [AppPalette.dark],
  );
}
