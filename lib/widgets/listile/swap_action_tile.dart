import 'package:flutter/material.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class SwapActionTile extends StatelessWidget {
  const SwapActionTile({
    super.key,
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.iconColor,
    this.textColor,
    this.opacity = 0.9,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color iconColor;
  final Color? textColor;
  final double opacity;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        width: 120,
        decoration: BoxDecoration(
          color: backgroundColor.withOpacity(opacity),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: backgroundColor.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon with animated container for visual feedback
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: iconColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: iconColor,
                  size: 28,
                ),
              ),
              const SizedBox(height: 12),

              // Text with improved styling
              Text(
                text,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: textColor ?? AppTheme.textPrimaryColor,
                  letterSpacing: 0.3,
                ),
                textAlign: TextAlign.center,
              )
            ],
          ),
        ),
      ),
    );
  }
}

// Animated version for more interactive feedback
class AnimatedSwapActionTile extends StatefulWidget {
  const AnimatedSwapActionTile({
    super.key,
    required this.icon,
    required this.text,
    required this.backgroundColor,
    required this.iconColor,
    this.textColor,
    this.opacity = 0.9,
    this.onTap,
  });

  final IconData icon;
  final String text;
  final Color backgroundColor;
  final Color iconColor;
  final Color? textColor;
  final double opacity;
  final VoidCallback? onTap;

  @override
  State<AnimatedSwapActionTile> createState() => _AnimatedSwapActionTileState();
}

class _AnimatedSwapActionTileState extends State<AnimatedSwapActionTile> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );

    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _controller.forward(),
      onTapUp: (_) => _controller.reverse(),
      onTapCancel: () => _controller.reverse(),
      onTap: widget.onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          height: 120,
          width: 120,
          decoration: BoxDecoration(
            color: widget.backgroundColor.withOpacity(widget.opacity),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.backgroundColor.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: widget.iconColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    widget.icon,
                    color: widget.iconColor,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.text,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: widget.textColor ?? AppTheme.textPrimaryColor,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                )
              ],
            ),
          ),
        ),
      ),
    );
  }
}
