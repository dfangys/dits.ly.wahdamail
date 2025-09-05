import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/features/home/presentation/screens/home/widgets/app_bar_icon.dart';
import 'package:wahda_bank/features/search/presentation/screens/search/search_view.dart';

Widget appBar() {
  return AppBar(
    elevation: 0,
    backgroundColor: Colors.white,
    title: GestureDetector(
      onTap: () {
        Get.to(() => SearchView());
      },
      child: Container(
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.grey.shade100,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 2,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.search, color: Colors.grey.shade700, size: 20),
              const SizedBox(width: 12),
              Text(
                'search'.tr,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
                  fontWeight: FontWeight.normal,
                ),
              ),
              const Spacer(),
              Container(
                width: 1,
                height: 24,
                color: Colors.grey.shade300,
                margin: const EdgeInsets.symmetric(horizontal: 8),
              ),
              Icon(
                Icons.mic_none_rounded,
                color: Colors.grey.shade600,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    ),
    actions: const [HomeAppBarIcon()],
  );
}
