import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/features/view/screens/splash.dart';
import 'package:wahda_bank/utills/constants/colors.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';

// ignore: must_be_immutable
class SendOtpView extends StatelessWidget {
  SendOtpView({super.key});

  bool isError = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: WColors.welcomeScafhold,
      body: Column(
        children: [
          const SizedBox(height: 80),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SvgPicture.asset(
              WImages.logo,
              fit: BoxFit.cover,
              // ignore: deprecated_member_use
              color: Colors.white,
              width: Get.width * 0.7,
            ),
          ),
          const SizedBox(height: 30),
          Expanded(
              child: Container(
            margin: const EdgeInsets.only(top: 5),
            decoration: BoxDecoration(
              color: Theme.of(context).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(25),
                topRight: Radius.circular(25),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    isError ? "Error in sending OTP" : "Sending OTP",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  if (!isError) const CircularProgressIndicator.adaptive(),
                  const SizedBox(height: 10),
                  if (isError)
                    SizedBox(
                      height: 50,
                      width: MediaQuery.of(context).size.width - 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                            shadowColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            )),
                        onPressed: () {},
                        child: const Text('Resend'),
                      ),
                    ),
                  if (isError)
                    Container(
                      height: 50,
                      margin: const EdgeInsets.only(top: 10),
                      width: MediaQuery.of(context).size.width - 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: () async {
                          Get.offAll(() => const SplashScreen());
                        },
                        child: const Text('Logout'),
                      ),
                    ),
                ],
              ),
            ),
          ))
        ],
      ),
    );
  }
}
