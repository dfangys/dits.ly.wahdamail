import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/otp_controller.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';

class SendOtpView extends StatefulWidget {
  const SendOtpView({super.key});
  @override
  State<SendOtpView> createState() => _SendOtpViewState();
}

class _SendOtpViewState extends State<SendOtpView> {
  final controller = Get.find<OtpController>();
  bool isError = false;
  bool isSuccess = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      controller.requestOtp();
    });
    controller.isError.listen((p) {
      setState(() {
        isError = p;
      });
    });
    controller.isSuccess.listen((p) {
      setState(() {
        isSuccess = p;
      });
    });
  }

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
              WImages.logoWhite,
              fit: BoxFit.cover,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isError
                          ? "error_in_sending_otp".tr
                          : isSuccess
                          ? "msg_otp_sent_successfully".tr
                          : "msg_sending_otp".tr,
                      style: Theme.of(
                        context,
                      ).textTheme.headlineSmall!.copyWith(
                        color:
                            isError
                                ? Colors.red
                                : isSuccess
                                ? Colors.green
                                : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 10),
                    if (!isError) const CircularProgressIndicator.adaptive(),
                    const SizedBox(height: 10),
                    if (isError || isSuccess)
                      SizedBox(
                        height: 50,
                        width: MediaQuery.of(context).size.width - 50,
                        child: Obx(() {
                          final secs = controller.resendSeconds.value;
                          final busy = controller.isRequestingOtp.value;
                          final canResend = secs == 0 && !busy;
                          final label =
                              secs == 0
                                  ? 'resend'.tr
                                  : '${'resend'.tr} (${secs}s)';
                          return OutlinedButton(
                            style: ElevatedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            onPressed: canResend ? controller.resendOtp : null,
                            child: Text(label),
                          );
                        }),
                      ),
                    if (isError || isSuccess)
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
                            controller.logout();
                          },
                          child: Text(
                            'logout'.tr,
                            style: const TextStyle(color: Colors.white),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
