import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import '../../views/settings/data/swap_data.dart';

class ListTileCupertinoDilaogue extends GetView<SettingController> {
  const ListTileCupertinoDilaogue({
    super.key,
    required this.direction,
  });

  final String direction;

  @override
  Widget build(BuildContext context) {
    SwapSettingData data = SwapSettingData();
    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppTheme.surfaceColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle bar for better UX
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Title
          Text(
            direction == "LTR" ? "Left to Right Actions" : "Right to Left Actions",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimaryColor,
            ),
          ),

          const SizedBox(height: 8),

          // Subtitle
          Text(
            "Select an action for ${direction == "LTR" ? "left" : "right"} swipe gesture",
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondaryColor,
            ),
          ),

          const SizedBox(height: 24),

          // Grid of options
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
            ),
            itemBuilder: (context, index) {
              final actionKey = data.swapActions.keys.elementAt(index);
              final actionWidget = data.swapActions.values.elementAt(index);

              // Extract icon and text from the widget
              Widget? icon;
              String actionName = actionKey.name.toString();

              if (actionWidget is Column) {
                icon = actionWidget.children.first;
              }

              return InkWell(
                onTap: () {
                  if (direction == "LTR") {
                    controller.swipeGesturesLTR(actionName);
                  } else {
                    controller.swipeGesturesRTL(actionName);
                  }

                  // Show feedback before closing
                  Get.snackbar(
                    'Swipe Action Set',
                    '${direction == "LTR" ? "Left" : "Right"} swipe set to $actionName',
                    snackPosition: SnackPosition.BOTTOM,
                    backgroundColor: AppTheme.primaryColor.withOpacity(0.9),
                    colorText: Colors.white,
                    margin: const EdgeInsets.all(16),
                    borderRadius: 12,
                    duration: const Duration(seconds: 2),
                  );

                  Navigator.pop(context);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.surfaceColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Use the original icon if available, otherwise create a placeholder
                      icon ?? Icon(
                        Icons.gesture,
                        color: AppTheme.primaryColor,
                        size: 32,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        actionName,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.textPrimaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            },
            itemCount: data.swapActions.length,
          ),

          const SizedBox(height: 16),

          // Cancel button
          Center(
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                "Cancel",
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
