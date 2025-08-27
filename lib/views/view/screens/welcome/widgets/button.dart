import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/authantication/screens/login/login.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';

class WelcomeButton extends StatelessWidget {
  const WelcomeButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 50,
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: WSizes.md),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(WSizes.buttonRadius),
          ),
          elevation: 5,
        ),
        onPressed: () {
          Get.to(() => const LoginScreen());
        },
        child: const Text(
          "Get Started",
          style: TextStyle(color: Colors.white, fontSize: 16.0),
        ),
      ),
    );
  }
}
