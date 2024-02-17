import 'package:background_fetch/background_fetch.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/views/authantication/screens/login/login.dart';
import 'package:wahda_bank/views/view/screens/drawer/terms_and_conditions.dart';
import 'package:wahda_bank/views/view/screens/drawer/contact_us/Contact_us.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/widgets/drawer/drawer_tile.dart';
import '../../services/mail_service.dart';
import '../../utills/extensions.dart';
import '../../views/settings/settings_view.dart';

class Drawer1 extends StatelessWidget {
  const Drawer1({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MailBoxController>();
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.green,
              Colors.green.shade800,
            ],
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  DrawerHeader(
                    decoration: const BoxDecoration(
                      color: Color(0xFF0A993C),
                    ),
                    child: Container(
                      margin: const EdgeInsets.only(
                          left: 10, right: 30, top: 0, bottom: 0),
                      child: SvgPicture.asset(
                        WImages.logo,
                        // ignore: deprecated_member_use
                        color: Colors.white,
                      ),
                    ),
                  ),
                  WDraweTile(
                    image: WImages.compose,
                    text: 'compose'.tr,
                    onTap: () {
                      Get.to(() => ComposeScreen());
                    },
                    trailing: '',
                  ),
                  divider(),
                  for (Mailbox box in controller.mailboxes)
                    Column(
                      children: [
                        WDraweTile(
                          image: boxIcon(box.name),
                          text: box.encodedName.ucFirst(),
                          onTap: () {
                            Get.back();
                            if (!box.isInbox) {
                              controller.navigatToMailBox(box);
                            }
                          },
                          trailing: box.messagesUnseen.toString(),
                        ),
                        divider(),
                      ],
                    ),
                ],
              ),
            ),
            WDraweTile(
              image: Icons.settings,
              text: 'settings'.tr,
              onTap: () {
                Get.to(() => const SettingsView());
              },
              trailing: '',
            ),
            divider(),
            WDraweTile(
              image: WImages.contactus,
              text: 'contact_us'.tr,
              onTap: () {
                Get.to(() => ContactUsScreen());
              },
              trailing: '',
            ),
            divider(),
            WDraweTile(
              image: WImages.files,
              text: 'terms_and_condition'.tr,
              onTap: () {
                Get.to(() => const TermsAndCondition());
              },
              trailing: '',
            ),
            divider(),
            WDraweTile(
              image: Icons.logout,
              text: 'logout'.tr,
              onTap: () async {
                await GetStorage().erase();
                MailService.instance.client.disconnect();
                MailService.instance.dispose();
                await controller.deleteAccount();
                await BackgroundFetch.stop();
                Get.offAll(() => LoginScreen());
              },
              trailing: '',
            ),
          ],
        ),
      ),
    );
  }
}

Widget divider() {
  return const Divider(
    height: 0,
    indent: 20,
    endIndent: 20,
    color: Colors.white,
    thickness: 0.3,
  );
}

IconData boxIcon(String name) {
  name = name.toLowerCase();
  late IconData icon;
  switch (name) {
    case 'inbox':
      icon = Icons.inbox;
      break;
    case 'sent':
      icon = Icons.send;
      break;
    case 'spam':
    case 'junk':
      icon = Icons.error;
      break;
    case 'trash':
      icon = Icons.delete;
      break;
    case 'drafts':
      icon = Icons.drafts;
      break;
    case 'flagged':
      icon = Icons.flag;
      break;
    default:
      icon = Icons.folder;
  }
  return icon;
}

String boxImage(String name) {
  name = name.toLowerCase();
  late String path;
  switch (name) {
    case 'inbox':
      path = 'inbox';
      break;
    case 'sent':
      path = 'sent';
      break;
    case 'spam':
      path = 'spam';
      break;
    case 'trash':
      path = 'delete';
      break;
    case 'drafts':
      path = 'draft';
      break;
    case 'flagged':
      path = 'flagged';
      break;
    default:
      path = 'inbox';
  }
  return "assets/$path.png";
}
