import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/view/screens/home/widgets/app_bar_icon.dart';
import 'package:wahda_bank/widgets/search/search.dart';

Widget appBar() {
  return AppBar(
    title: GestureDetector(
      onTap: () {
        SearchController().clear();
        Get.to(
          SearchView(),
        );
      },
      child: Container(
        height: 40,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.shade300,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Text(
                'search'.tr,
                style: TextStyle(color: Colors.grey.shade700),
              ),
              const Spacer(),
              Container(
                width: 1,
                height: 20,
                color: Colors.grey.shade400,
                margin: const EdgeInsets.symmetric(horizontal: 5),
              ),
              GestureDetector(
                onTap: () {},
                child: const Icon(
                  Icons.search,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    actions: const [
      HomeAppBarIcon(),
    ],
  );
}
