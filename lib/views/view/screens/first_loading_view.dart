import 'package:awesome_dialog/awesome_dialog.dart';
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
        BackgroundFetch.scheduleTask(
          TaskConfig(
            taskId: 'com.transistorsoft.customtask',
            delay: 15 * 60 * 1000,
            requiredNetworkType: NetworkType.ANY,
            startOnBoot: true,
            enableHeadless: true,
            periodic: true,
          ),
        );
        Get.offAllNamed('/home');
      } else {
        AwesomeDialog(
          context: Get.context!,
          dialogType: DialogType.error,
          title: 'Error',
          desc:
              'An error occurred while trying to connect to the server. $error',
        ).show();
      }
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
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      height: 105.0,
                      width: 273,
                      child: SvgPicture.asset(
                        WImages.logo,
                      ),
                    ),
                    const SizedBox(height: 10),
                    const CircularProgressIndicator(
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
