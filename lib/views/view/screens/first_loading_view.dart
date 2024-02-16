import 'package:background_fetch/background_fetch.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/views/view/models/box_model.dart';
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

  String error = '';

  Future init() async {
    bool isReadyToRun = true;
    try {
      if (!storage.hasData('first_run')) {
        await MailService.instance.init();
        await MailService.instance.connect();
        List<Mailbox> boxes = await MailService.instance.client.listMailboxes();
        List<Map<String, dynamic>> v = [];
        for (var box in boxes) {
          v.add(BoxModel.toJson(box));
        }
        await storage.write('boxes', v);
        await storage.write('first_run', true);
      }
    } catch (e) {
      isReadyToRun = false;
      printError(info: e.toString());
      error = e.toString();
    } finally {
      if (isReadyToRun) {
        int status = await BackgroundFetch.status;
        if (status == BackgroundFetch.STATUS_RESTRICTED ||
            status == BackgroundFetch.STATUS_DENIED) {
        } else {
          BackgroundFetch.start();
        }
        Get.offAllNamed('/home');
      } else {}
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
                      const CircularProgressIndicator(
                        color: Colors.white,
                      ),
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
