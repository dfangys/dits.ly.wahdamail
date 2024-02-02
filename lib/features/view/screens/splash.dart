import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/features/view/screens/welcome/welcome.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    Future.delayed(
        const Duration(seconds: 2), () => Get.to(() => const WelcomeScreen()));
    super.initState();
  }

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
                image: AssetImage(WImages.background),
                fit: BoxFit.cover,
              )),
              child: Center(
                child: SizedBox(
                  width: MediaQuery.of(context).size.width - 50,
                  child: InkWell(
                    onTap: () {},
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
