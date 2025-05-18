import 'package:flutter/material.dart';

/// Helper class for fixing widget parameter issues
class WidgetParameterFixes {
  /// Fix for backgroundColor parameter that isn't defined
  static Color? resolveBackgroundColor(BuildContext context, Color? color) {
    // In newer Flutter versions, some widgets might use different parameter names
    // This helper provides a way to handle the color correctly
    return color ?? Theme.of(context).cardColor;
  }
  
  /// Fix for duration parameter that isn't defined
  static Duration resolveDuration(Duration? duration) {
    // Some widgets might not accept duration parameter in newer versions
    // This helper provides a default value
    return duration ?? const Duration(milliseconds: 300);
  }
  
  /// Fix for onTapLink parameter that isn't defined
  static void defaultOnTapLink(String url) {
    // Default implementation for link tapping
    debugPrint('Link tapped: $url');
    // Additional handling can be added here
  }
}
