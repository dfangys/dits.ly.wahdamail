import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:iconsax/iconsax.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/views/view/screens/drawer/terms_and_conditions.dart';
import 'package:wahda_bank/views/view/screens/drawer/contact_us/Contact_us.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/widgets/drawer/drawer_tile.dart';
import '../../app/controllers/mail_count_controller.dart';
import '../../views/settings/settings_view.dart';

class Drawer1 extends StatelessWidget {
  const Drawer1({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MailBoxController>();
    final countController = Get.find<MailCountController>();
    return Drawer(
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.8),
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
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
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
                    image: Iconsax.edit5,
                    text: 'compose'.tr,
                    onTap: () {
                      Get.to(() => const ComposeScreen());
                    },
                    trailing: '',
                  ),
                  divider(),
                  for (Mailbox box in controller.sortedMailBoxes)
                    Column(
                      children: [
                        WDraweTile(
                          image: boxIcon(box.name),
                          text: box.encodedName.toLowerCase().tr,
                          onTap: () {
                            Get.back();
                            if (!box.isInbox) {
                              controller.navigatToMailBox(box);
                            }
                          },
                          trailing: (countController.counts[
                                      "${box.name.toLowerCase()}_count"] ??
                                  0)
                              .toString(),
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
              image: CupertinoIcons.doc_text,
              text: 'terms_and_condition'.tr,
              onTap: () {
                Get.to(() => const TermsAndCondition());
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
