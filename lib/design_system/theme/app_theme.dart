// lib/design_system/theme/app_theme.dart
import 'package:flutter/material.dart';
import 'package:wahda_bank/design_system/theme/tokens.dart';
import 'package:wahda_bank/design_system/theme/typography.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart' as legacy;

class AppThemeDS {
  AppThemeDS._();

  // Light theme maps 1:1 to existing legacy theme for zero visual diffs
  static ThemeData get light {
    // Defer to legacy theme to ensure perfect parity
    final base = legacy.AppTheme.getLightTheme();
    return base.copyWith(
      textTheme: TypographyDS.textTheme(),
      colorScheme: base.colorScheme.copyWith(
        primary: Tokens.brand,
        error: Tokens.error,
        surface: Tokens.surface,
      ),
      scaffoldBackgroundColor: Tokens.background,
    );
  }

  // Dark theme placeholder (parity-focused; no behavioral change)
  static ThemeData get dark {
    // Using light theme for now to avoid unexpected diffs; dark palette can be introduced behind a flag later
    return light;
  }
}
