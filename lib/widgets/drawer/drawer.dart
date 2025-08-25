import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:iconsax/iconsax.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/mail_count_controller.dart';
import 'package:wahda_bank/views/view/screens/drawer/terms_and_conditions.dart';
import 'package:wahda_bank/views/view/screens/drawer/contact_us/Contact_us.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import 'package:wahda_bank/views/settings/settings_view.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/widgets/drawer/drawer_tile.dart';

class Drawer1 extends StatelessWidget {
  const Drawer1({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MailBoxController>();
    final countController = Get.find<MailCountController>();
    final theme = Theme.of(context);

    return Drawer(
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.primaryColor,
              theme.primaryColor.withValues(alpha : 0.9),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha : 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with logo and close button
            _buildDrawerHeader(context),

            // Main content scrollable area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha : 0.1),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(24),
                    topLeft: Radius.circular(24),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(24),
                    topLeft: Radius.circular(24),
                  ),
                  child: ListView(
                    padding: EdgeInsets.zero,
                    physics: const BouncingScrollPhysics(),
                    children: [
                      const SizedBox(height: 16),

                      // Compose button
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _buildComposeButton(context),
                      ),

                      const SizedBox(height: 24),

                      // Mailboxes section
                      Padding(
                        padding: const EdgeInsets.only(left: 24, bottom: 8),
                        child: Text(
                          'mailboxes'.tr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha : 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      // Mailbox list
                      for (Mailbox box in controller.mailBoxes)
                        WDrawerTile(
                          icon: boxIcon(box.name),
                          text: box.encodedName.toLowerCase().tr,
                          onTap: () {
                            Get.back();
                            if (!box.isInbox) {
                              controller.navigatToMailBox(box);
                            }
                          },
                          count: countController.counts["${box.name.toLowerCase()}_count"] ?? 0,
                          isActive: box.isInbox,
                        ),

                      const SizedBox(height: 24),

                      // Settings section
                      Padding(
                        padding: const EdgeInsets.only(left: 24, bottom: 8),
                        child: Text(
                          'preferences'.tr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha : 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      // Settings options
                      WDrawerTile(
                        icon: Iconsax.setting_2,
                        text: 'settings'.tr,
                        onTap: () {
                          Get.to(() => const SettingsView());
                        },
                      ),

                      WDrawerTile(
                        icon: Iconsax.message_question,
                        text: 'contact_us'.tr,
                        onTap: () {
                          Get.to(() => ContactUsScreen());
                        },
                      ),

                      WDrawerTile(
                        icon: Iconsax.document_text,
                        text: 'terms_and_condition'.tr,
                        onTap: () {
                          Get.to(() => const TermsAndCondition());
                        },
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),

            // App version at bottom
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'v1.0.0',
                style: TextStyle(
                  color: Colors.white.withValues(alpha : 0.5),
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          SvgPicture.asset(
            WImages.logo,
            height: 40,
            // ignore: deprecated_member_use
            color: Colors.white,
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha : 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComposeButton(BuildContext context) {
    return InkWell(
      onTap: () {
        Get.to(() => const ComposeScreen());
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha : 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Iconsax.edit,
              color: Colors.green,
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              'compose'.tr,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData boxIcon(String name) {
  name = name.toLowerCase();
  switch (name) {
    case 'inbox':
      return Iconsax.direct_inbox;
    case 'sent':
      return Iconsax.send_2;
    case 'spam':
    case 'junk':
      return Iconsax.shield_cross;
    case 'trash':
      return Iconsax.trash;
    case 'drafts':
      return Iconsax.document_1;
    case 'flagged':
      return Iconsax.flag;
    default:
      return Iconsax.folder_2;
  }
}
