import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/widgets/search/search.dart';

class WSearchBar extends StatelessWidget {
  const WSearchBar({
    super.key,
    this.hintText = 'Search emails',
    this.onTap,
  });

  final String hintText;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap ?? () {
        // Clear previous search results
        Get.find<SearchController>().clear();
        // Navigate to search view
        Get.to(
              () => SearchView(),
          transition: Transition.downToUp,
          duration: const Duration(milliseconds: 300),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppTheme.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Search icon
              Icon(
                Icons.search_rounded,
                color: AppTheme.textSecondaryColor,
                size: 20,
              ),

              const SizedBox(width: 12),

              // Hint text
              Text(
                hintText,
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondaryColor,
                  fontWeight: FontWeight.w400,
                ),
              ),

              const Spacer(),

              // Voice search option
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Enhanced version with animation
class WAnimatedSearchBar extends StatefulWidget {
  const WAnimatedSearchBar({
    super.key,
    this.hintText = 'Search emails',
    this.onTap,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
  });

  final String hintText;
  final VoidCallback? onTap;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final bool autofocus;

  @override
  State<WAnimatedSearchBar> createState() => _WAnimatedSearchBarState();
}

class _WAnimatedSearchBarState extends State<WAnimatedSearchBar> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  final FocusNode _focusNode = FocusNode();
  final TextEditingController _textController = TextEditingController();
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _focusNode.addListener(() {
      setState(() {
        _isExpanded = _focusNode.hasFocus;
      });
    });

    if (widget.autofocus) {
      Future.delayed(const Duration(milliseconds: 300), () {
        _focusNode.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _focusNode.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _isExpanded ? 1.0 : _pulseAnimation.value,
          child: child,
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: AppTheme.surfaceColor,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: _isExpanded
                ? AppTheme.primaryColor.withOpacity(0.5)
                : Colors.grey.withOpacity(0.2),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              // Search icon
              Icon(
                Icons.search_rounded,
                color: _isExpanded
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondaryColor,
                size: 20,
              ),

              const SizedBox(width: 12),

              // Text field or hint text
              Expanded(
                child: TextField(
                  controller: _textController,
                  focusNode: _focusNode,
                  decoration: InputDecoration(
                    hintText: widget.hintText,
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: AppTheme.textSecondaryColor,
                      fontWeight: FontWeight.w400,
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimaryColor,
                    fontWeight: FontWeight.w400,
                  ),
                  onChanged: widget.onChanged,
                  onSubmitted: widget.onSubmitted,
                  textInputAction: TextInputAction.search,
                ),
              ),

              // Clear button (only when text is entered)
              if (_textController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear, size: 18),
                  onPressed: () {
                    _textController.clear();
                    if (widget.onChanged != null) {
                      widget.onChanged!('');
                    }
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  splashRadius: 20,
                ),

              // Voice search option
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _isExpanded
                      ? AppTheme.primaryColor.withOpacity(0.2)
                      : AppTheme.primaryColor.withOpacity(0.1),
                ),
                child: Icon(
                  Icons.mic_rounded,
                  color: AppTheme.primaryColor,
                  size: 18,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
