import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class WSliverAppBar extends StatelessWidget {
  const WSliverAppBar({
    super.key,
    this.title = '',
    this.expandedHeight = 120,
    this.actions,
    this.onBackPressed,
    this.backLabel = 'accounts',
    this.showEditButton = true,
    this.onEditPressed,
  });

  final String title;
  final double expandedHeight;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final String backLabel;
  final bool showEditButton;
  final VoidCallback? onEditPressed;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppTheme.surfaceColor,
      pinned: true,
      expandedHeight: expandedHeight,
      elevation: 0,
      automaticallyImplyLeading: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        centerTitle: true,
        titlePadding: const EdgeInsets.only(bottom: 16),
        title: Text(
          title.isEmpty ? 'inbox'.tr : title,
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        background: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
          ),
          child: Stack(
            children: [
              // Decorative elements
              Positioned(
                top: -20,
                right: -20,
                child: Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryColor.withOpacity(0.05),
                  ),
                ),
              ),
              Positioned(
                bottom: 10,
                left: -30,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryColor.withOpacity(0.05),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      title: GestureDetector(
        onTap: onBackPressed ?? Get.back,
        child: Row(
          children: [
            Icon(
              CupertinoIcons.back,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              backLabel.tr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryColor,
              ),
            )
          ],
        ),
      ),
      actions: actions ?? [
        if (showEditButton)
          TextButton(
            onPressed: onEditPressed ?? () {},
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(
              'edit'.tr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
      ],
    );
  }
}

// Enhanced version with animations
class WAnimatedSliverAppBar extends StatelessWidget {
  const WAnimatedSliverAppBar({
    super.key,
    this.title = '',
    this.expandedHeight = 120,
    this.actions,
    this.onBackPressed,
    this.backLabel = 'accounts',
    this.showEditButton = true,
    this.onEditPressed,
    this.showSearchField = false,
    this.onSearchChanged,
  });

  final String title;
  final double expandedHeight;
  final List<Widget>? actions;
  final VoidCallback? onBackPressed;
  final String backLabel;
  final bool showEditButton;
  final VoidCallback? onEditPressed;
  final bool showSearchField;
  final Function(String)? onSearchChanged;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      backgroundColor: AppTheme.surfaceColor,
      pinned: true,
      expandedHeight: expandedHeight,
      elevation: 0,
      automaticallyImplyLeading: false,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(16),
        ),
      ),
      flexibleSpace: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          // Calculate the percentage of expansion
          final expandRatio = (constraints.maxHeight - kToolbarHeight) / (expandedHeight - kToolbarHeight);
          final expandPercentage = (expandRatio > 1.0) ? 1.0 : (expandRatio < 0.0) ? 0.0 : expandRatio;

          return FlexibleSpaceBar(
            centerTitle: expandPercentage < 0.5, // Center when collapsed
            titlePadding: EdgeInsets.only(
              bottom: 16 * expandPercentage,
              left: expandPercentage < 0.5 ? 0 : 16,
              right: 16,
            ),
            title: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: expandPercentage > 0.5 ? 1.0 : 0.0,
              child: showSearchField && expandPercentage > 0.7
                  ? _buildSearchField()
                  : Text(
                title.isEmpty ? 'inbox'.tr : title,
                style: TextStyle(
                  color: AppTheme.textPrimaryColor,
                  fontSize: 18 * (0.8 + (expandPercentage * 0.2)), // Slightly scale with expansion
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            background: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppTheme.surfaceColor,
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(16),
                ),
              ),
              child: Stack(
                children: [
                  // Animated decorative elements
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    top: -20 + (20 * (1.0 - expandPercentage)),
                    right: -20 + (20 * (1.0 - expandPercentage)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 100 * expandPercentage,
                      height: 100 * expandPercentage,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryColor.withOpacity(0.05 * expandPercentage),
                      ),
                    ),
                  ),
                  AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    bottom: 10 * expandPercentage,
                    left: -30 + (30 * (1.0 - expandPercentage)),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 80 * expandPercentage,
                      height: 80 * expandPercentage,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.primaryColor.withOpacity(0.05 * expandPercentage),
                      ),
                    ),
                  ),

                  // Title for collapsed state
                  Positioned(
                    bottom: 16,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 300),
                      opacity: expandPercentage < 0.5 ? 1.0 : 0.0,
                      child: Center(
                        child: Text(
                          title.isEmpty ? 'inbox'.tr : title,
                          style: TextStyle(
                            color: AppTheme.textPrimaryColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
      title: GestureDetector(
        onTap: onBackPressed ?? Get.back,
        child: Row(
          children: [
            Icon(
              CupertinoIcons.back,
              color: AppTheme.primaryColor,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              backLabel.tr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryColor,
              ),
            )
          ],
        ),
      ),
      actions: actions ?? [
        if (showEditButton)
          TextButton(
            onPressed: onEditPressed ?? () {},
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
            child: Text(
              'edit'.tr,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.primaryColor,
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSearchField() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey.withOpacity(0.2),
        ),
      ),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'search_emails'.tr,
          hintStyle: TextStyle(
            fontSize: 14,
            color: AppTheme.textSecondaryColor,
          ),
          prefixIcon: Icon(
            Icons.search,
            color: AppTheme.textSecondaryColor,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
        style: TextStyle(
          fontSize: 14,
          color: AppTheme.textPrimaryColor,
        ),
        onChanged: onSearchChanged,
      ),
    );
  }
}
