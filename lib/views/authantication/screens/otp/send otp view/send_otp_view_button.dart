import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/authantication/screens/otp/enter_otp/enter_otp.dart';
import 'package:wahda_bank/views/view/screens/splash.dart';

class SendOtpViewBotton extends StatelessWidget {
  const SendOtpViewBotton({
    super.key,
    required this.isError,
  });

  final bool isError;

  @override
  Widget build(BuildContext context) {
    return Column(
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
            child: TextButton(
              style: ElevatedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Get.to(() => const EnterOtpScreen());
              },
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
              child: const Text(
                'Logout',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
      ],
    );
  }
}
