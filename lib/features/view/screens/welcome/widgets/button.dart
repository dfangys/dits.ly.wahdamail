import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/features/authantication/screens/login/login.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';

class WelcomeButton extends StatelessWidget {
  const WelcomeButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        Get.to(LoginScreen());
      },
      child: Container(
        height: 45,
        width: MediaQuery.of(context).size.width - 50,
        decoration: BoxDecoration(
            color: Colors.green,
            borderRadius: BorderRadius.circular(WSizes.borderRadiusLg)),
        child: const Center(
            child: Text(
          "Get Started",
          style: TextStyle(color: Colors.white),
        )),
      ),
    );
  }
}
