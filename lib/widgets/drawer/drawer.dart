import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/authantication/screens/login/login.dart';
import 'package:wahda_bank/views/view/screens/drawer/send_mail/send_mail.dart';
import 'package:wahda_bank/views/view/screens/drawer/terms_and_conditions.dart';
import 'package:wahda_bank/views/view/screens/drawer/contact_us/Contact_us.dart';
import 'package:wahda_bank/views/view/screens/drawer/starred.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import 'package:wahda_bank/utills/constants/colors.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/widgets/drawer/drawer_tile.dart';
import 'package:wahda_bank/views/view/screens/drawer/trash.dart';

import '../../views/settings/settings_view.dart';

class Drawer1 extends StatelessWidget {
  const Drawer1({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: WColors.welcomeScafhold,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              color: Color(0xFF0A993C),
            ),
            child: Container(
              margin:
                  const EdgeInsets.only(left: 10, right: 30, top: 0, bottom: 0),
              child: SvgPicture.asset(
                WImages.logo,
                // ignore: deprecated_member_use
                color: Colors.white,
              ),
            ),
          ),
          WDraweTile(
            image: WImages.compose,
            text: 'Compose',
            onTap: () {
              Get.to(() => ComposeScreen());
            },
            trailing: '',
          ),
          divider(),
          WDraweTile(
            image: WImages.inbox,
            text: 'Inbox',
            onTap: () => Get.back(),
            trailing: '99',
          ),
          divider(),
          WDraweTile(
            image: WImages.sent,
            text: 'Sent Mail',
            onTap: () {
              Get.to(() => const SendMailScreen(
                    title: 'Send',
                  ));
            },
            trailing: '',
          ),
          divider(),
          WDraweTile(
            image: WImages.draft,
            text: 'Drafts',
            onTap: () {
              Get.to(() => const SendMailScreen(
                    title: 'Drafts',
                  ));
            },
            trailing: '',
          ),
          divider(),
          WDraweTile(
            image: WImages.delete,
            text: 'Trash',
            onTap: () {
              Get.to(() => const TrashScreen());
            },
            trailing: '',
          ),
          divider(),
          WDraweTile(
            image: WImages.star,
            text: 'Starred',
            onTap: () {
              Get.to(() => const StarredScreen());
            },
            trailing: '',
          ),
          divider(),
          WDraweTile(
            image: WImages.spam,
            text: 'Spam',
            onTap: () {
              Get.to(() => const SendMailScreen(
                    title: 'Spam',
                  ));
            },
            trailing: '',
          ),
          divider(),
          WDraweTile(
            image: WImages.draft,
            text: 'Settings',
            onTap: () {
              Get.to(() => const SettingsView());
            },
            trailing: '',
          ),
          divider(),
          WDraweTile(
            image: WImages.contactus,
            text: 'Contact Us',
            onTap: () {
              Get.to(() => ContactUsScreen());
            },
            trailing: '',
          ),
          divider(),
          WDraweTile(
            image: WImages.files,
            text: 'Terms and Condition',
            onTap: () {
              Get.to(() => const TermsAndCondition());
            },
            trailing: '',
          ),
          divider(),
          ListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 25),
            leading: const Icon(
              Icons.logout,
              color: Colors.white,
              size: 20,
            ),
            title: const Text(
              'Log Out',
              style: TextStyle(color: Colors.white),
            ),
            onTap: () => Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => LoginScreen())),
          ),
        ],
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
  );
}
