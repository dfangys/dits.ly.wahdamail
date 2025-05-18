import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class HomeAppBarIcon extends StatelessWidget {
  const HomeAppBarIcon({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: 'compose_button',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          onTap: () {
            Get.to(
                  () => const ComposeScreen(),
              transition: Transition.rightToLeft,
              duration: AppTheme.mediumAnimationDuration,
            );
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              color: AppTheme.primaryColor,
              boxShadow: [
                BoxShadow(
                  color: AppTheme.primaryColor.withOpacity(0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Center(
              child: Icon(
                Icons.add,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
