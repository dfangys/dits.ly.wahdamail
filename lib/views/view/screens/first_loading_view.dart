import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import '../../../services/mail_service.dart';
import '../../../utills/constants/image_strings.dart';

class LoadingFirstView extends StatefulWidget {
  const LoadingFirstView({super.key});

  @override
  State<LoadingFirstView> createState() => _LoadingFirstViewState();
}

class _LoadingFirstViewState extends State<LoadingFirstView> {
  final GetStorage storage = GetStorage();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((timeStamp) {
      init();
    });
  }

  Future init() async {
    try {
      await MailService.instance.init();
      if (MailService.instance.isConnected && !storage.hasData('first_run')) {
        if (MailService.instance.isConnected) {
          await MailService.instance.client.listMailboxes(order: [
            MailboxFlag.inbox,
            MailboxFlag.sent,
            MailboxFlag.drafts,
            MailboxFlag.trash,
            MailboxFlag.junk,
            MailboxFlag.flagged,
          ]);
        }
        await storage.write('first_run', true);
      }
      Get.offAllNamed('/home');
    } catch (e) {
      printError(info: e.toString());
    }
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
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      InkWell(
                        onTap: () {},
                        child: SvgPicture.asset(
                          WImages.logo,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const CircularProgressIndicator(),
                    ],
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
