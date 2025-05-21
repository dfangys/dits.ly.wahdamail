import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class TAnimationLoaderWidget extends StatelessWidget {
  const TAnimationLoaderWidget({
    super.key,
    required this.text,
    required this.animation,
    this.showAction = false,
    this.actionText,
    this.onActionPressed,
  });

  final String text;
  final String animation;
  final bool showAction;
  final String? actionText;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = MediaQuery.of(context).size;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            /// Animation
            Lottie.asset(
              animation,
              width: size.width * 0.7,
              fit: BoxFit.contain,
              repeat: true,
            ),

            const SizedBox(height: 20),

            /// Message
            Text(
              text,
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onBackground,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            /// Optional Action Button
            if (showAction && actionText != null)
              SizedBox(
                width: 260,
                height: 48,
                child: FilledButton.tonal(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onActionPressed,
                  child: Text(
                    actionText!,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600, color: Colors.white
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}