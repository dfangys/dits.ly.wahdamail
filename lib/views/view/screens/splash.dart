import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/views/authantication/screens/login/login.dart';
import 'package:wahda_bank/views/view/screens/first_loading_view.dart';
import 'package:wahda_bank/views/view/screens/welcome/welcome.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';

import '../../../services/notifications_service.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final storage = GetStorage();
  @override
  void initState() {
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) async {
      await NotificationService.instance.setup();
      if (storage.read('email') != null && storage.read('password') != null) {
        if (storage.read('otp') != null) {
          Get.offAll(() => const LoadingFirstView());
        } else {
          Get.offAll(() => LoginScreen());
        }
      } else {
        Get.offAll(() => const WelcomeScreen());
      }
    });
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        constraints: const BoxConstraints.expand(),
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage(WImages.background),
            fit: BoxFit.cover,
          ),
        ),
        child: Center(
          child: SizedBox(
            height: 105.0,
            width: 273,
            child: SvgPicture.asset(
              WImages.logo,
            ),
          ),
        ),
      ),
    );
  }
}
