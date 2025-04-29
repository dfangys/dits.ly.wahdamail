// ignore_for_file: file_names

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:rounded_loading_button/rounded_loading_button.dart';
import 'package:wahda_bank/views/authantication/screens/login/widgets/rounded_button.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';

// ignore: must_be_immutable
class ContactUsScreen extends StatelessWidget {
  RoundedLoadingButtonController controller = RoundedLoadingButtonController();

  RoundedLoadingButtonController controller1 = RoundedLoadingButtonController();

  ContactUsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Contact Us",
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Card(
              elevation: 5,
              color: Colors.white,
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  const Stack(
                    children: [
                      Icon(Iconsax.sms, size: WSizes.iconXlg,color: Colors.green,),
                      // Icon(Iconsax.sms, size: WSizes.iconLg,),

                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "info@wahdabank.com",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  WRoundedButton(
                    controller: controller1,
                    onPress: () {
                      Get.to(
                        () => const ComposeScreen(),
                        arguments: {'support': 'info@wahdabank.com'},
                      );
                      controller1.stop();
                    },
                    text: "Email",
                  ),
                  const SizedBox(height: WSizes.spaceBtwSections),
                ],
              ),
            ),
            Card(
              elevation: 5,
              color: Colors.white,
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 30),
                  const Stack(
                    children: [
                      Icon(Iconsax.call_calling4, size: WSizes.iconXlg,color: Colors.green,),
                      Icon(Iconsax.call, size: WSizes.iconXlg,),

                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    "+218 61 2224256",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 10),
                  WRoundedButton(
                    controller: controller,
                    onPress: () async {
                      Future.delayed(const Duration(seconds: 3), () {
                        controller.stop();
                      });
                    },
                    text: 'Call',
                  ),
                  const SizedBox(height: WSizes.spaceBtwSections),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
