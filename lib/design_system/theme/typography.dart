// lib/design_system/theme/typography.dart
import 'package:flutter/material.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart' as legacy;

class TypographyDS {
  static const String defaultFont = 'sfp';

  static TextTheme textTheme({bool isArabic = false}) {
    final family = isArabic ? 'arb' : defaultFont;
    // Map to legacy AppTheme text sizes/weights
    return TextTheme(
      displayLarge: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: legacy.AppTheme.textPrimaryColor, fontFamily: family),
      displayMedium: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: legacy.AppTheme.textPrimaryColor, fontFamily: family),
      displaySmall: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: legacy.AppTheme.textPrimaryColor, fontFamily: family),
      headlineMedium: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: legacy.AppTheme.textPrimaryColor, fontFamily: family),
      headlineSmall: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: legacy.AppTheme.textPrimaryColor, fontFamily: family),
      titleLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: legacy.AppTheme.textPrimaryColor, fontFamily: family),
      titleMedium: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: legacy.AppTheme.textPrimaryColor, fontFamily: family),
      titleSmall: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: legacy.AppTheme.textPrimaryColor, fontFamily: family),
      bodyLarge: TextStyle(fontSize: 16, fontWeight: FontWeight.normal, color: legacy.AppTheme.textPrimaryColor, fontFamily: family),
      bodyMedium: TextStyle(fontSize: 14, fontWeight: FontWeight.normal, color: legacy.AppTheme.textPrimaryColor, fontFamily: family),
      bodySmall: TextStyle(fontSize: 12, fontWeight: FontWeight.normal, color: legacy.AppTheme.textSecondaryColor, fontFamily: family),
      labelLarge: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: legacy.AppTheme.primaryColor, fontFamily: family),
    );
  }
}

