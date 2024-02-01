import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/features/view/screens/welcome/welcome.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Stack(
          children: [
            Container(
              height: 200,
              width: MediaQuery.of(context).size.width - 35,
              constraints: const BoxConstraints.expand(),
              decoration: const BoxDecoration(
                  image: DecorationImage(
                image: AssetImage('assets/png/background.png'),
                fit: BoxFit.cover,
              )),
              child: Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 50,
                  child: InkWell(
                    onTap: () {
                      Get.to(const WelcomeScreen());
                    },
                    child: SvgPicture.asset(
                      WImages.logo,
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
