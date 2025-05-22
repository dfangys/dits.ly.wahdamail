import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:get/get.dart';
import 'dart:ui';

class TAnimationLoaderWidget extends StatelessWidget {
  final String? title;
  final String? description;
  final String? animationPath;
  final double? width;
  final double? height;
  final bool showRefreshButton;
  final VoidCallback? onRefresh;

  // Backward compatibility parameters
  final String? text;
  final String? animation;
  final bool? showAction;
  final String? actionText;
  final VoidCallback? onActionPressed;

  const TAnimationLoaderWidget({
    Key? key,
    this.title,
    this.description,
    this.animationPath,
    this.width,
    this.height,
    this.showRefreshButton = false,
    this.onRefresh,
    // Backward compatibility parameters
    this.text,
    this.animation,
    this.showAction,
    this.actionText,
    this.onActionPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    // Use either new or old parameter names for backward compatibility
    final displayTitle = title ?? text ?? '';
    final displayDescription = description ?? '';
    final displayAnimation = animationPath ?? animation ?? '';
    final shouldShowAction = showAction ?? showRefreshButton;
    final displayActionText = actionText ?? 'refresh'.tr;
    final actionCallback = onActionPressed ?? onRefresh;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade900.withOpacity(0.7) : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black26 : Colors.grey.shade200,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animation
                Lottie.asset(
                  displayAnimation,
                  width: width ?? 180,
                  height: height ?? 180,
                  fit: BoxFit.contain,
                  frameRate: FrameRate.max,
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    displayTitle,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Description
                if (displayDescription.isNotEmpty)
                  Text(
                    displayDescription,
                    style: TextStyle(
                      fontSize: 14,
                      color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                    ),
                    textAlign: TextAlign.center,
                  ),

                // Action button if needed
                if (shouldShowAction && actionCallback != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: ElevatedButton.icon(
                      onPressed: actionCallback,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text(displayActionText),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class EmptyBoxWidget extends StatelessWidget {
  final String title;
  final String description;
  final String imagePath;
  final double? width;
  final double? height;
  final bool showActionButton;
  final String? actionButtonText;
  final VoidCallback? onAction;

  const EmptyBoxWidget({
    Key? key,
    required this.title,
    required this.description,
    required this.imagePath,
    this.width,
    this.height,
    this.showActionButton = false,
    this.actionButtonText,
    this.onAction,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade900.withOpacity(0.7) : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black26 : Colors.grey.shade200,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image
                Image.asset(
                  imagePath,
                  width: width ?? 180,
                  height: height ?? 180,
                  fit: BoxFit.contain,
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Action button if needed
                if (showActionButton && onAction != null && actionButtonText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: ElevatedButton(
                      onPressed: onAction,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                      child: Text(actionButtonText!),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NoResultsWidget extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onAction;
  final String? actionText;

  const NoResultsWidget({
    Key? key,
    required this.title,
    required this.description,
    this.onAction,
    this.actionText,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade900.withOpacity(0.7) : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black26 : Colors.grey.shade200,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: isDarkMode ? Colors.grey.shade800 : Colors.grey.shade200,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? theme.colorScheme.primary.withOpacity(0.2)
                        : theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.search_off_rounded,
                    size: 40,
                    color: theme.colorScheme.primary,
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Action button if needed
                if (onAction != null && actionText != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: Text(actionText!),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Renamed to avoid conflict with Flutter's ErrorWidget
class ErrorDisplayWidget extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback? onRetry;

  const ErrorDisplayWidget({
    Key? key,
    required this.title,
    required this.description,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: isDarkMode ? Colors.grey.shade900.withOpacity(0.7) : Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: isDarkMode ? Colors.black26 : Colors.grey.shade200,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
          border: Border.all(
            color: isDarkMode ? Colors.red.shade800.withOpacity(0.3) : Colors.red.shade100,
            width: 1,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Error icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: isDarkMode
                        ? Colors.red.shade900.withOpacity(0.2)
                        : Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    size: 40,
                    color: Colors.red.shade600,
                  ),
                ),

                // Title
                Padding(
                  padding: const EdgeInsets.only(top: 16, bottom: 8),
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDarkMode ? Colors.white : Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Description
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: isDarkMode ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),

                // Retry button if needed
                if (onRetry != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: ElevatedButton.icon(
                      onPressed: onRetry,
                      icon: const Icon(Icons.refresh_rounded),
                      label: Text('retry'.tr),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
