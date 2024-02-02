import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/features/authantication/screens/otp/send%20otp%20view/send_otp_view_button.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';

// ignore: must_be_immutable
class SendOtpView extends StatelessWidget {
  SendOtpView({super.key});

  bool isError = true;
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).primaryColor,
      body: Column(
        children: [
          const SizedBox(height: WSizes.imageThumbSize),
          Padding(
            padding: const EdgeInsets.all(WSizes.defaultSpace),
            child: SvgPicture.asset(
              WImages.logo,
              fit: BoxFit.cover,
              theme: const SvgTheme(currentColor: Colors.white),
              width: Get.width * 0.7,
            ),
          ),
          const SizedBox(height: WSizes.spaceBtwSections),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(25),
                  topRight: Radius.circular(25),
                ),
              ),
              child: Center(
                child: SendOtpViewBotton(isError: isError),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
