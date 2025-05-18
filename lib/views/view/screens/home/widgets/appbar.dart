import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/view/screens/home/widgets/app_bar_icon.dart';
import 'package:wahda_bank/widgets/search/search.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

PreferredSizeWidget appBar() {
  // Fix iOS status bar visibility
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
  ));

  return AppBar(
    elevation: 0,
    backgroundColor: AppTheme.surfaceColor,
    systemOverlayStyle: const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
    title: Hero(
      tag: 'search_bar',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTheme.borderRadius),
          onTap: () {
            Get.to(
                  () => SearchView(),
              transition: Transition.downToUp,
              duration: AppTheme.mediumAnimationDuration,
            );
          },
          child: Container(
            height: 44,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
              color: AppTheme.backgroundColor,
              border: Border.all(color: AppTheme.dividerColor),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: AppTheme.textSecondaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'search'.tr,
                    style: TextStyle(
                      color: AppTheme.textSecondaryColor,
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
    actions: const [
      HomeAppBarIcon(),
      SizedBox(width: 8), // Add some padding at the end
    ],
  );
}
