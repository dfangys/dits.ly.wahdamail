import 'package:flutter/material.dart';
import 'package:wahda_bank/views/view/screens/welcome/widgets/button.dart';
import 'package:wahda_bank/utills/constants/colors.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';
import 'package:wahda_bank/utills/constants/text_strings.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.height * 1;
    return Scaffold(
      backgroundColor: WColors.welcomeScafhold,
      body: Container(
        constraints: const BoxConstraints.expand(),
        margin: EdgeInsets.only(top: size * 0.06),
        decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
                topLeft: Radius.circular(25), topRight: Radius.circular(25))),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                margin: const EdgeInsets.only(
                    top: 50, bottom: 30, left: 20, right: 20),
                height: MediaQuery.of(context).size.height / 2.5,
                child: Image.asset(WImages.welcomeImage),
              ),
              Text(
                "Welcome",
                style: TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: size * 0.04),
              ),
              const SizedBox(
                width: 80,
                child: Divider(
                  height: 10,
                  thickness: 3,
                  color: WColors.welcomeScafhold,
                ),
              ),
              const SizedBox(height: WSizes.defaultSpace),
              const Text(
                WText.welcomeScreenTitle,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: WSizes.defaultSpace),
              const WelcomeButton(),
            ],
          ),
        ),
      ),
    );
  }
}
