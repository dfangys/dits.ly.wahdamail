import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';

class WAnimationLoaderWidget extends StatelessWidget {
  const WAnimationLoaderWidget(
      {super.key,
      required this.text,
      required this.animation,
      this.showAction = false,
      this.actionText,
      this.onActionPressed});
  final String text;
  final String animation;
  final bool showAction;
  final String? actionText;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    
    return Center(
      child: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: screenSize.height * 0.3,
            maxHeight: screenSize.height * 0.8,
            maxWidth: screenSize.width * 0.9,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Constrained Lottie animation
              SizedBox(
                width: screenSize.width * 0.6,
                height: screenSize.height * 0.3,
                child: Lottie.network(
                  animation,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    // Fallback if Lottie fails to load
                    return Icon(
                      Icons.email,
                      size: screenSize.width * 0.2,
                      color: Theme.of(context).primaryColor,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16.0),
              // Text with proper constraints
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  text,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(height: 16.0),
              // Action button if needed
              if (showAction && actionText != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: onActionPressed,
                      child: Text(
                        actionText!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).primaryColor,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
