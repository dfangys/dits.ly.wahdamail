import 'package:flutter/material.dart';
import 'dart:ui';

class AppTheme {
  // Brand colors - Vibrant modern palette
  static const Color starColor = Colors.amber; // Preserved from original theme
  static const MaterialColor primaryColor = MaterialColor(0xFF006633, {
    50: Color.fromRGBO(0, 102, 51, .1),
    100: Color.fromRGBO(0, 102, 51, .2),
    200: Color.fromRGBO(0, 102, 51, .3),
    300: Color.fromRGBO(0, 102, 51, .4),
    400: Color.fromRGBO(0, 102, 51, .5),
    500: Color.fromRGBO(0, 102, 51, .6),
    600: Color.fromRGBO(0, 102, 51, .7),
    700: Color.fromRGBO(0, 102, 51, .8),
    800: Color.fromRGBO(0, 102, 51, .9),
    900: Color.fromRGBO(0, 102, 51, 1),
  });
  static const Color cardDesignColor = Color(0xFFF8FAFC); // Preserved from original theme

  // Secondary colors
  static const Color secondaryColor = Color(0xFF7C3AED); // Vibrant purple
  static const Color accentColor = Color(0xFFEC4899); // Bright pink
  static const Color neutralColor = Color(0xFF1E293B); // Slate dark

  // Extended color palette
  static const Color successColor = Color(0xFF10B981); // Emerald
  static const Color warningColor = Color(0xFFF59E0B); // Amber
  static const Color errorColor = Color(0xFFEF4444); // Red
  static const Color infoColor = Color(0xFF3B82F6); // Blue

  // Background and surface colors
  static const Color backgroundColor = Color(0xFFF8FAFC); // Slate 50
  static const Color surfaceColor = Colors.white;
  static const Color surfaceVariantColor = Color(0xFFF1F5F9); // Slate 100

  // Text colors
  static const Color textPrimaryColor = Color(0xFF0F172A); // Slate 900
  static const Color textSecondaryColor = Color(0xFF475569); // Slate 600
  static const Color textTertiaryColor = Color(0xFF94A3B8); // Slate 400
  static const Color textOnPrimaryColor = Colors.white;
  static const Color textOnSecondaryColor = Colors.white;

  // Email specific colors
  static const Color unreadColor = Color(0xFFEFF6FF); // Blue 50
  static const Color attachmentIconColor = Color(0xFF64748B); // Slate 500
  static const Color dividerColor = Color(0xFFE2E8F0); // Slate 200
  static const Color swipeDeleteColor = Color(0xFFEF4444); // Red 500
  static const Color swipeArchiveColor = Color(0xFF10B981); // Emerald 500
  static const Color swipeFlagColor = Color(0xFFF59E0B); // Amber 500

  // Color palette for avatars and UI elements
  static const List<Color> colorPalette = [
    Color(0xFF2563EB), // Blue
    Color(0xFF10B981), // Emerald
    Color(0xFFEF4444), // Red
    Color(0xFF7C3AED), // Purple
    Color(0xFF84CC16), // Lime
    Color(0xFFF97316), // Orange
    Color(0xFF06B6D4), // Cyan
    Color(0xFF4F46E5), // Indigo
    Color(0xFF14B8A6), // Teal
    Color(0xFFEC4899), // Pink
    Color(0xFF78716C), // Stone
    Color(0xFF6B7280), // Gray
    Color(0xFF0EA5E9), // Sky
    Color(0xFF8B5CF6), // Violet
    Color(0xFF71717A), // Zinc
    Color(0xFFEAB308), // Yellow
  ];

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF006633), // Brand Green (Primary) - replaces Blue 600
      Color(0xFF00994D), // Accent Green (Secondary) - replaces Blue 500
    ],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF006633), // Wahda Bank - Primary Green
      Color(0xFF00994D), // Wahda Bank - Accent Green
    ],
  );

  static const LinearGradient successGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF059669), // Emerald 600
      Color(0xFF10B981), // Emerald 500
    ],
  );

  // Elevation and shadows - Subtle modern look
  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 12,
      offset: const Offset(0, 2),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.01),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
  ];

  static List<BoxShadow> elevatedShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 16,
      offset: const Offset(0, 4),
    ),
    BoxShadow(
      color: Colors.black.withOpacity(0.03),
      blurRadius: 6,
      offset: const Offset(0, 2),
    ),
  ];

  static List<BoxShadow> bottomNavShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.05),
      blurRadius: 10,
      offset: const Offset(0, -2),
    ),
  ];

  // Glassmorphism effect
  static BoxDecoration glassEffect = BoxDecoration(
    color: Colors.white.withOpacity(0.6),
    borderRadius: BorderRadius.circular(borderRadius),
    border: Border.all(
      color: Colors.white.withOpacity(0.2),
      width: 1,
    ),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withOpacity(0.03),
        blurRadius: 8,
        spreadRadius: 0,
      ),
    ],
  );

  // Rounded corners - Modern look
  static const double borderRadius = 16.0;
  static const double smallBorderRadius = 12.0;
  static const double largeBorderRadius = 24.0;
  static const double extraLargeBorderRadius = 32.0;
  static const double pillBorderRadius = 100.0;

  // Spacing - Enhanced for better visual hierarchy
  static const double spacing = 16.0;
  static const double smallSpacing = 8.0;
  static const double tinySpacing = 4.0;
  static const double mediumSpacing = 24.0;
  static const double largeSpacing = 32.0;
  static const double extraLargeSpacing = 48.0;

  // Animation durations
  static const Duration microAnimationDuration = Duration(milliseconds: 100);
  static const Duration shortAnimationDuration = Duration(milliseconds: 200);
  static const Duration mediumAnimationDuration = Duration(milliseconds: 300);
  static const Duration longAnimationDuration = Duration(milliseconds: 500);

  // Get light theme - Modern Material 3
  static ThemeData getLightTheme() {
    return ThemeData(
      useMaterial3: true,
      primarySwatch: primaryColor,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.light(
        primary: primaryColor,
        onPrimary: textOnPrimaryColor,
        primaryContainer: primaryColor.withOpacity(0.1),
        onPrimaryContainer: primaryColor,
        secondary: secondaryColor,
        onSecondary: textOnSecondaryColor,
        secondaryContainer: secondaryColor.withOpacity(0.1),
        onSecondaryContainer: secondaryColor,
        tertiary: accentColor,
        onTertiary: Colors.white,
        tertiaryContainer: accentColor.withOpacity(0.1),
        onTertiaryContainer: accentColor,
        error: errorColor,
        onError: Colors.white,
        errorContainer: errorColor.withOpacity(0.1),
        onErrorContainer: errorColor,
        background: backgroundColor,
        onBackground: textPrimaryColor,
        surface: surfaceColor,
        onSurface: textPrimaryColor,
        surfaceVariant: surfaceVariantColor,
        onSurfaceVariant: textSecondaryColor,
        outline: dividerColor,
        shadow: Colors.black.withOpacity(0.1),
        inverseSurface: neutralColor,
        onInverseSurface: Colors.white,
        inversePrimary: Colors.white,
        surfaceTint: primaryColor.withOpacity(0.05),
      ),
      scaffoldBackgroundColor: backgroundColor,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withOpacity(0.05),
        backgroundColor: surfaceColor,
        foregroundColor: textPrimaryColor,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: textPrimaryColor,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          fontFamily: 'sfp',
        ),
        iconTheme: const IconThemeData(color: primaryColor),
        actionsIconTheme: const IconThemeData(color: primaryColor),
        toolbarHeight: 64,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: surfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      listTileTheme: const ListTileThemeData(
        contentPadding: EdgeInsets.symmetric(horizontal: spacing, vertical: smallSpacing),
        minLeadingWidth: 24,
        minVerticalPadding: smallSpacing,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(smallBorderRadius)),
        ),
        tileColor: surfaceColor,
      ),
      dividerTheme: const DividerThemeData(
        color: dividerColor,
        thickness: 1,
        space: 1,
        indent: spacing,
        endIndent: spacing,
      ),
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(pillBorderRadius),
        ),
        elevation: 2,
        highlightElevation: 4,
        extendedPadding: const EdgeInsets.symmetric(horizontal: spacing, vertical: smallSpacing),
        extendedTextStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          letterSpacing: 0.5,
          fontFamily: 'sfp',
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceColor,
        selectedItemColor: primaryColor,
        unselectedItemColor: textSecondaryColor,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        selectedIconTheme: const IconThemeData(size: 24),
        unselectedIconTheme: const IconThemeData(size: 24),
        selectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
          fontFamily: 'sfp',
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.normal,
          fontSize: 12,
          fontFamily: 'sfp',
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfaceColor,
        indicatorColor: primaryColor.withOpacity(0.1),
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(
              color: primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
              fontFamily: 'sfp',
            );
          }
          return const TextStyle(
            color: textSecondaryColor,
            fontSize: 12,
            fontWeight: FontWeight.normal,
            fontFamily: 'sfp',
          );
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(
              color: primaryColor,
              size: 24,
            );
          }
          return const IconThemeData(
            color: textSecondaryColor,
            size: 24,
          );
        }),
        elevation: 0,
        height: 80,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariantColor,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: spacing,
          vertical: spacing,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: errorColor, width: 1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(borderRadius),
          borderSide: const BorderSide(color: errorColor, width: 1.5),
        ),
        hintStyle: const TextStyle(
          color: textTertiaryColor,
          fontSize: 16,
          fontWeight: FontWeight.normal,
          fontFamily: 'sfp',
        ),
        labelStyle: const TextStyle(
          color: textSecondaryColor,
          fontSize: 16,
          fontWeight: FontWeight.normal,
          fontFamily: 'sfp',
        ),
        floatingLabelStyle: const TextStyle(
          color: primaryColor,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'sfp',
        ),
        prefixIconColor: textSecondaryColor,
        suffixIconColor: textSecondaryColor,
        isDense: true,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
          letterSpacing: -0.5,
          height: 1.2,
          fontFamily: 'sfp',
        ),
        displayMedium: TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
          letterSpacing: -0.5,
          height: 1.2,
          fontFamily: 'sfp',
        ),
        displaySmall: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: textPrimaryColor,
          letterSpacing: -0.25,
          height: 1.3,
          fontFamily: 'sfp',
        ),
        headlineLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimaryColor,
          letterSpacing: -0.25,
          height: 1.3,
          fontFamily: 'sfp',
        ),
        headlineMedium: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
          letterSpacing: -0.25,
          height: 1.4,
          fontFamily: 'sfp',
        ),
        headlineSmall: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
          letterSpacing: -0.25,
          height: 1.4,
          fontFamily: 'sfp',
        ),
        titleLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
          letterSpacing: 0,
          height: 1.4,
          fontFamily: 'sfp',
        ),
        titleMedium: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
          letterSpacing: 0,
          height: 1.4,
          fontFamily: 'sfp',
        ),
        titleSmall: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
          letterSpacing: 0,
          height: 1.4,
          fontFamily: 'sfp',
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimaryColor,
          letterSpacing: 0.1,
          height: 1.5,
          fontFamily: 'sfp',
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textPrimaryColor,
          letterSpacing: 0.1,
          height: 1.5,
          fontFamily: 'sfp',
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.normal,
          color: textSecondaryColor,
          letterSpacing: 0.2,
          height: 1.5,
          fontFamily: 'sfp',
        ),
        labelLarge: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: primaryColor,
          letterSpacing: 0.1,
          height: 1.4,
          fontFamily: 'sfp',
        ),
        labelMedium: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: primaryColor,
          letterSpacing: 0.5,
          height: 1.4,
          fontFamily: 'sfp',
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: textSecondaryColor,
          letterSpacing: 0.5,
          height: 1.4,
          fontFamily: 'sfp',
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: primaryColor.withOpacity(0.3),
          padding: const EdgeInsets.symmetric(
            horizontal: spacing * 1.5,
            vertical: spacing,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(pillBorderRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            fontFamily: 'sfp',
          ),
          minimumSize: const Size(64, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryColor,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing,
            vertical: smallSpacing,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(pillBorderRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            fontFamily: 'sfp',
          ),
          minimumSize: const Size(64, 40),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primaryColor,
          side: const BorderSide(color: primaryColor, width: 1.5),
          padding: const EdgeInsets.symmetric(
            horizontal: spacing * 1.5,
            vertical: spacing,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(pillBorderRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            fontFamily: 'sfp',
          ),
          minimumSize: const Size(64, 48),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: spacing * 1.5,
            vertical: spacing,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(pillBorderRadius),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
            fontFamily: 'sfp',
          ),
          minimumSize: const Size(64, 48),
        ),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return Colors.transparent;
        }),
        checkColor: MaterialStateProperty.all(Colors.white),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(smallBorderRadius / 2),
        ),
        side: const BorderSide(width: 1.5, color: textTertiaryColor),
      ),
      radioTheme: RadioThemeData(
        fillColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return textTertiaryColor;
        }),
        splashRadius: 24,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor;
          }
          return Colors.white;
        }),
        trackColor: MaterialStateProperty.resolveWith<Color>((states) {
          if (states.contains(MaterialState.selected)) {
            return primaryColor.withOpacity(0.4);
          }
          return textTertiaryColor.withOpacity(0.3);
        }),
        trackOutlineColor: MaterialStateProperty.resolveWith<Color>((states) {
          return Colors.transparent;
        }),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: primaryColor,
        circularTrackColor: primaryColor.withOpacity(0.1),
        linearTrackColor: primaryColor.withOpacity(0.1),
        refreshBackgroundColor: backgroundColor,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surfaceVariantColor,
        disabledColor: surfaceVariantColor.withOpacity(0.6),
        selectedColor: primaryColor.withOpacity(0.1),
        secondarySelectedColor: secondaryColor.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        labelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: textPrimaryColor,
          fontFamily: 'sfp',
        ),
        secondaryLabelStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: primaryColor,
          fontFamily: 'sfp',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(pillBorderRadius),
        ),
        side: BorderSide.none,
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: primaryColor,
        inactiveTrackColor: primaryColor.withOpacity(0.2),
        thumbColor: primaryColor,
        overlayColor: primaryColor.withOpacity(0.2),
        trackHeight: 4,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 12),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
      ),
      tabBarTheme: TabBarTheme(
        labelColor: primaryColor,
        unselectedLabelColor: textSecondaryColor,
        indicatorColor: primaryColor,
        indicatorSize: TabBarIndicatorSize.label,
        labelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
          fontFamily: 'sfp',
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
          fontFamily: 'sfp',
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: neutralColor.withOpacity(0.9),
          borderRadius: BorderRadius.circular(smallBorderRadius),
        ),
        textStyle: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          fontFamily: 'sfp',
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: neutralColor,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          fontFamily: 'sfp',
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        behavior: SnackBarBehavior.floating,
        actionTextColor: primaryColor,
      ),
      dialogTheme: DialogTheme(
        backgroundColor: surfaceColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(largeBorderRadius),
        ),
        titleTextStyle: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimaryColor,
          letterSpacing: -0.25,
          fontFamily: 'sfp',
        ),
        contentTextStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: textPrimaryColor,
          letterSpacing: 0.1,
          height: 1.5,
          fontFamily: 'sfp',
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: surfaceColor,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(largeBorderRadius),
          ),
        ),
        modalBackgroundColor: surfaceColor,
        modalElevation: 8,
      ),
      badgeTheme: const BadgeThemeData(
        backgroundColor: primaryColor,
        textColor: Colors.white,
        textStyle: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          fontFamily: 'sfp',
        ),
        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
      bannerTheme: MaterialBannerThemeData(
        backgroundColor: surfaceColor,
        contentTextStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: textPrimaryColor,
          fontFamily: 'sfp',
        ),
        padding: const EdgeInsets.all(spacing),
      ),
      dividerColor: dividerColor,
      splashColor: primaryColor.withOpacity(0.1),
      highlightColor: primaryColor.withOpacity(0.05),
      splashFactory: InkRipple.splashFactory,
      fontFamily: 'sfp',
    );
  }

  // Get dark theme - Modern Material 3
  static ThemeData getDarkTheme() {
    const Color darkBackgroundColor = Color(0xFF0F172A); // Slate 900
    const Color darkSurfaceColor = Color(0xFF1E293B); // Slate 800
    const Color darkSurfaceVariantColor = Color(0xFF334155); // Slate 700

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primarySwatch: primaryColor,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.dark(
        primary: primaryColor,
        onPrimary: Colors.white,
        primaryContainer: primaryColor.withOpacity(0.2),
        onPrimaryContainer: Colors.white,
        secondary: secondaryColor,
        onSecondary: Colors.white,
        secondaryContainer: secondaryColor.withOpacity(0.2),
        onSecondaryContainer: Colors.white,
        tertiary: accentColor,
        onTertiary: Colors.white,
        tertiaryContainer: accentColor.withOpacity(0.2),
        onTertiaryContainer: Colors.white,
        error: errorColor,
        onError: Colors.white,
        errorContainer: errorColor.withOpacity(0.2),
        onErrorContainer: Colors.white,
        background: darkBackgroundColor,
        onBackground: Colors.white,
        surface: darkSurfaceColor,
        onSurface: Colors.white,
        surfaceVariant: darkSurfaceVariantColor,
        onSurfaceVariant: Colors.white.withOpacity(0.7),
        outline: Colors.white.withOpacity(0.2),
        shadow: Colors.black,
        inverseSurface: Colors.white,
        onInverseSurface: textPrimaryColor,
        inversePrimary: primaryColor,
        surfaceTint: Colors.white.withOpacity(0.05),
      ),
      scaffoldBackgroundColor: darkBackgroundColor,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 1,
        shadowColor: Colors.black.withOpacity(0.2),
        backgroundColor: darkSurfaceColor,
        foregroundColor: Colors.white,
        centerTitle: false,
        titleTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
          fontFamily: 'sfp',
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        toolbarHeight: 64,
      ),
      cardTheme: CardTheme(
        elevation: 0,
        color: darkSurfaceColor,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        clipBehavior: Clip.antiAlias,
        margin: EdgeInsets.zero,
      ),
      // Additional dark theme configurations would follow the same pattern
      fontFamily: 'sfp',
    );
  }

  // Helper methods for modern UI effects

  // Create a frosted glass effect container
  static Widget frostedGlassContainer({
    required Widget child,
    double borderRadius = borderRadius,
    Color? backgroundColor,
    EdgeInsetsGeometry padding = const EdgeInsets.all(spacing),
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (backgroundColor ?? Colors.white).withOpacity(0.7),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: child,
        ),
      ),
    );
  }

  // Create a gradient container
  static Widget gradientContainer({
    required Widget child,
    double borderRadius = borderRadius,
    LinearGradient? gradient,
    EdgeInsetsGeometry padding = const EdgeInsets.all(spacing),
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: gradient ?? primaryGradient,
        boxShadow: [
          BoxShadow(
            color: (gradient?.colors.first ?? primaryColor).withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // Create a card with shadow
  static Widget shadowCard({
    required Widget child,
    double borderRadius = borderRadius,
    Color? backgroundColor,
    EdgeInsetsGeometry padding = const EdgeInsets.all(spacing),
    List<BoxShadow>? boxShadow,
  }) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? surfaceColor,
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ?? cardShadow,
      ),
      child: child,
    );
  }
}
