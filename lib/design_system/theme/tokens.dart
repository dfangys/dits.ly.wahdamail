// lib/design_system/theme/tokens.dart
import 'package:flutter/material.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart' as legacy;

class Tokens {
  // Spacing
  static const double space2 = 4;
  static const double space3 = 8;
  static const double space4 = 12;
  static const double space5 = 16; // legacy.spacing
  static const double space6 = 24; // legacy.largeSpacing

  // Radii
  static const double radiusSm = 8; // legacy.smallBorderRadius
  static const double radiusMd = 12; // legacy.borderRadius
  static const double radiusLg = 16; // legacy.largeBorderRadius

  // Durations
  static const Duration durSm = Duration(milliseconds: 100);
  static const Duration durMd = legacy.AppTheme.mediumAnimationDuration;
  static const Duration durLg = legacy.AppTheme.longAnimationDuration;

  // Elevation levels (soft mapping)
  static const List<BoxShadow> shadowCard = [];

  // Colors (1:1 mapping to legacy theme)
  static const MaterialColor brand = legacy.AppTheme.primaryColor;
  static const Color surface = legacy.AppTheme.surfaceColor;
  static const Color background = legacy.AppTheme.backgroundColor;
  static const Color error = legacy.AppTheme.errorColor;
  static const Color success = legacy.AppTheme.successColor;
  static const Color warning = legacy.AppTheme.warningColor;
  static const Color info = legacy.AppTheme.infoColor;

  static const Color textPrimary = legacy.AppTheme.textPrimaryColor;
  static const Color textSecondary = legacy.AppTheme.textSecondaryColor;
  static const Color textTertiary = legacy.AppTheme.textTertiaryColor;

  static const Color divider = legacy.AppTheme.dividerColor;
}

