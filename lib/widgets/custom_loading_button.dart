import 'package:flutter/material.dart';

enum ButtonState { idle, loading, success, error }

class CustomLoadingButtonController {
  ButtonState _state = ButtonState.idle;
  VoidCallback? _stateChangeCallback;

  ButtonState get state => _state;

  void setStateChangeCallback(VoidCallback callback) {
    _stateChangeCallback = callback;
  }

  void start() {
    _state = ButtonState.loading;
    _stateChangeCallback?.call();
  }

  void stop() {
    _state = ButtonState.idle;
    _stateChangeCallback?.call();
  }

  void success() {
    _state = ButtonState.success;
    _stateChangeCallback?.call();

    // Auto reset after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (_state == ButtonState.success) {
        stop();
      }
    });
  }

  void error() {
    _state = ButtonState.error;
    _stateChangeCallback?.call();

    // Auto reset after 2 seconds
    Future.delayed(const Duration(seconds: 2), () {
      if (_state == ButtonState.error) {
        stop();
      }
    });
  }

  void reset() {
    _state = ButtonState.idle;
    _stateChangeCallback?.call();
  }
}

class CustomLoadingButton extends StatefulWidget {
  const CustomLoadingButton({
    super.key,
    required this.controller,
    required this.onPressed,
    required this.child,
    this.color,
    this.borderRadius = 10,
    this.elevation = 3,
    this.width,
    this.height = 50,
    this.successColor,
    this.errorColor,
  });

  final CustomLoadingButtonController controller;
  final VoidCallback? onPressed;
  final Widget child;
  final Color? color;
  final double borderRadius;
  final double elevation;
  final double? width;
  final double height;
  final Color? successColor;
  final Color? errorColor;

  @override
  State<CustomLoadingButton> createState() => _CustomLoadingButtonState();
}

class _CustomLoadingButtonState extends State<CustomLoadingButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    widget.controller.setStateChangeCallback(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color get _buttonColor {
    switch (widget.controller.state) {
      case ButtonState.success:
        return widget.successColor ?? Colors.green;
      case ButtonState.error:
        return widget.errorColor ?? Colors.red;
      default:
        return widget.color ?? Theme.of(context).primaryColor;
    }
  }

  Widget get _buttonChild {
    switch (widget.controller.state) {
      case ButtonState.loading:
        return SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(
              Theme.of(context).colorScheme.onPrimary,
            ),
          ),
        );
      case ButtonState.success:
        return Icon(
          Icons.check,
          color: Theme.of(context).colorScheme.onPrimary,
        );
      case ButtonState.error:
        return Icon(
          Icons.close,
          color: Theme.of(context).colorScheme.onPrimary,
        );
      default:
        return widget.child;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _animationController.forward(),
      onTapUp: (_) => _animationController.reverse(),
      onTapCancel: () => _animationController.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: _buttonColor,
            borderRadius: BorderRadius.circular(widget.borderRadius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: widget.elevation,
                offset: Offset(0, widget.elevation / 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              onTap:
                  widget.controller.state == ButtonState.loading
                      ? null
                      : widget.onPressed,
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _buttonChild,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// Legacy compatibility aliases
typedef RoundedLoadingButtonController = CustomLoadingButtonController;
typedef RoundedLoadingButton = CustomLoadingButton;
