import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/views/view/screens/drawer/terms_and_conditions.dart';
import 'package:wahda_bank/views/view/screens/drawer/contact_us/Contact_us.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
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
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Theme.of(context).primaryColor,
              Theme.of(context).primaryColor.withOpacity(0.9),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(16),
            bottomRight: Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(2, 0),
            ),
          ],
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with logo
              _buildDrawerHeader(context),

              // Compose button
              _buildComposeButton(context),

              const SizedBox(height: 8),

              // Mailboxes list
              Expanded(
                child: _buildMailboxesList(controller, countController),
              ),

              // Bottom actions
              _buildBottomActions(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(16),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: SvgPicture.asset(
              WImages.logo,
              // ignore: deprecated_member_use
              color: Colors.white,
              height: 40,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Whada Bank',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Mail',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () {
          Get.back();
          Get.to(
                () => const ComposeScreen(),
            transition: Transition.rightToLeft,
            duration: AppTheme.mediumAnimationDuration,
          );
        },
        icon: const Icon(Icons.edit, color: Colors.green),
        label: Text(
          'compose'.tr,
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Theme.of(context).primaryColor,
          elevation: 0,
          minimumSize: const Size(double.infinity, 48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildMailboxesList(MailBoxController controller, MailCountController countController) {
    return ListView(
      padding: EdgeInsets.zero,
      children: [
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
                trailing: (countController.counts["${box.name.toLowerCase()}_count"] ?? 0).toString(),
                isSelected: box.isInbox,
              ),
              modernDivider(),
            ],
          ),
      ],
    );
  }

  Widget _buildBottomActions(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          bottomRight: Radius.circular(16),
        ),
      ),
      child: Column(
        children: [
          modernDivider(),
          WDraweTile(
            image: Icons.settings,
            text: 'settings'.tr,
            onTap: () {
              Get.back();
              Get.to(
                    () => const SettingsView(),
                transition: Transition.rightToLeft,
                duration: AppTheme.mediumAnimationDuration,
              );
            },
            trailing: '',
          ),
          modernDivider(),
          WDraweTile(
            image: WImages.contactus,
            text: 'contact_us'.tr,
            onTap: () {
              Get.back();
              Get.to(
                    () => ContactUsScreen(),
                transition: Transition.rightToLeft,
                duration: AppTheme.mediumAnimationDuration,
              );
            },
            trailing: '',
          ),
          modernDivider(),
          WDraweTile(
            image: WImages.files,
            text: 'terms_and_condition'.tr,
            onTap: () {
              Get.back();
              Get.to(
                    () => const TermsAndCondition(),
                transition: Transition.rightToLeft,
                duration: AppTheme.mediumAnimationDuration,
              );
            },
            trailing: '',
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

Widget modernDivider() {
  return Divider(
    height: 1,
    indent: 16,
    endIndent: 16,
    color: Colors.white.withOpacity(0.2),
    thickness: 0.5,
  );
}

IconData boxIcon(String name) {
  name = name.toLowerCase();
  late IconData icon;
  switch (name) {
    case 'inbox':
      icon = Icons.inbox_rounded;
      break;
    case 'sent':
      icon = Icons.send_rounded;
      break;
    case 'spam':
    case 'junk':
      icon = Icons.error_rounded;
      break;
    case 'trash':
      icon = Icons.delete_rounded;
      break;
    case 'drafts':
      icon = Icons.drafts_rounded;
      break;
    case 'flagged':
      icon = Icons.flag_rounded;
      break;
    default:
      icon = Icons.folder_rounded;
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
