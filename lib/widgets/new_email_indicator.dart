import 'package:flutter/material.dart';
import '../services/incoming_email_service.dart';

/// Animated indicator for new email notifications
class NewEmailIndicator extends StatefulWidget {
  const NewEmailIndicator({super.key});

  @override
  State<NewEmailIndicator> createState() => _NewEmailIndicatorState();
}

class _NewEmailIndicatorState extends State<NewEmailIndicator>
    with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  int _newEmailCount = 0;

  @override
  void initState() {
    super.initState();

    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _slideController, curve: Curves.elasticOut),
    );

    // Listen to new email count
    _listenToNewEmails();
  }

  void _listenToNewEmails() {
    final incomingService = IncomingEmailService.instance;

    incomingService.newEmailCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _newEmailCount = count;
        });

        if (count > 0) {
          _showNewEmailAnimation();
        } else {
          _hideIndicator();
        }
      }
    });
  }

  void _showNewEmailAnimation() {
    // Slide in
    _slideController.forward();

    // Start pulsing
    _pulseController.repeat(reverse: true);
  }

  void _hideIndicator() {
    // Stop pulsing
    _pulseController.stop();

    // Slide out
    _slideController.reverse();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_newEmailCount == 0) {
      return const SizedBox.shrink();
    }

    return SlideTransition(
      position: _slideAnimation,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _pulseAnimation.value,
            child: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade400, Colors.blue.shade600],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.blue.withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.email, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _newEmailCount == 1
                        ? '1 new email'
                        : '$_newEmailCount new emails',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 6),
                  GestureDetector(
                    onTap: () {
                      // Reset count and hide indicator
                      IncomingEmailService.instance.resetNewEmailCount();
                    },
                    child: const Icon(
                      Icons.close,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Floating action button with new email count
class NewEmailFAB extends StatefulWidget {
  final VoidCallback? onPressed;

  const NewEmailFAB({super.key, this.onPressed});

  @override
  State<NewEmailFAB> createState() => _NewEmailFABState();
}

class _NewEmailFABState extends State<NewEmailFAB>
    with SingleTickerProviderStateMixin {
  late AnimationController _bounceController;
  late Animation<double> _bounceAnimation;

  int _newEmailCount = 0;

  @override
  void initState() {
    super.initState();

    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    _bounceAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _bounceController, curve: Curves.elasticOut),
    );

    // Listen to new emails
    IncomingEmailService.instance.newEmailCountStream.listen((count) {
      if (mounted) {
        setState(() {
          _newEmailCount = count;
        });

        if (count > 0) {
          _bounceController.forward().then((_) {
            _bounceController.reverse();
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _bounceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _bounceAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _bounceAnimation.value,
          child: Stack(
            children: [
              FloatingActionButton(
                onPressed: widget.onPressed,
                child: const Icon(Icons.refresh),
              ),
              if (_newEmailCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    child: Text(
                      _newEmailCount > 99 ? '99+' : '$_newEmailCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
