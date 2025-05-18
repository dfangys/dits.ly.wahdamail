import 'package:flutter/material.dart';

/// Extension methods for OverlayEntry class
extension OverlayEntryExtensions on OverlayEntry {
  /// Safely removes this overlay entry from its overlay
  void dismiss() {
    // In newer Flutter versions, dismiss() doesn't exist
    // This extension provides backward compatibility
    if (mounted) {
      remove();
    }
  }
}
