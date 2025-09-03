import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:get/get.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:iconsax/iconsax.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/mail_count_controller.dart';
import 'package:wahda_bank/views/view/screens/drawer/terms_and_conditions.dart';
import 'package:wahda_bank/views/view/screens/drawer/contact_us/Contact_us.dart';
import 'package:wahda_bank/views/compose/widgets/compose_modal.dart';
import 'package:wahda_bank/views/settings/settings_view.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/widgets/drawer/drawer_tile.dart';
import 'package:wahda_bank/views/settings/pages/performance_flags_page.dart';
import 'package:wahda_bank/app/controllers/settings_controller.dart';

class Drawer1 extends StatelessWidget {
  const Drawer1({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<MailBoxController>();
    final countController = Get.find<MailCountController>();
    final settingController =
        Get.isRegistered<SettingController>()
            ? Get.find<SettingController>()
            : Get.put(SettingController(), permanent: true);
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
              theme.primaryColor.withValues(alpha: 0.9),
            ],
          ),
          borderRadius: const BorderRadius.only(
            topRight: Radius.circular(24),
            bottomRight: Radius.circular(24),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header with logo and close button + profile info
            _buildDrawerHeader(context, settingController),

            // Main content scrollable area
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
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
                            color: Colors.white.withValues(alpha: 0.7),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),

                      // Mailbox list - sorted by priority
                      for (Mailbox box in _getSortedMailboxes(
                        controller.mailboxes,
                      ))
                        WDrawerTile(
                          icon: boxIcon(box.name),
                          text: box.encodedName.toLowerCase().tr,
                          onTap: () {
                            Get.back();
                            if (!box.isInbox) {
                              controller.navigatToMailBox(box);
                            }
                          },
                          count:
                              countController
                                  .counts["${box.name.toLowerCase()}_count"] ??
                              0,
                          isActive: box.isInbox,
                        ),

                      const SizedBox(height: 24),

                      // Settings section
                      Padding(
                        padding: const EdgeInsets.only(left: 24, bottom: 8),
                        child: Text(
                          'preferences'.tr,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.7),
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

                      // Monitoring + Feature Flags
                      WDrawerTile(
                        icon: Iconsax.activity,
                        text: 'Performance & Flags',
                        onTap: () {
                          Get.to(() => const PerformanceFlagsPage());
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

            // Usage + App version at bottom
            _buildUsageFooter(context, settingController),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerHeader(
    BuildContext context,
    SettingController settingController,
  ) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 48, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: SvgPicture.asset(
                  WImages.logoWhite,
                  height: 40,
                  colorFilter: const ColorFilter.mode(
                    Colors.white,
                    BlendMode.srcIn,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Obx(() {
            final name = settingController.userName().trim();
            final email = settingController.userEmail().trim();
            final displayName =
                name.isNotEmpty
                    ? name
                    : (email.isNotEmpty ? email.split('@').first : 'User');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    letterSpacing: 0.2,
                  ),
                ),
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontWeight: FontWeight.w400,
                      fontSize: 13,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildUsageFooter(
    BuildContext context,
    SettingController settingController,
  ) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Obx(() {
          final usageLabel =
              settingController.usageLabel().isNotEmpty
                  ? settingController.usageLabel()
                  : '';
          final quotaLabel =
              settingController.quotaLabel().isNotEmpty
                  ? settingController.quotaLabel()
                  : '';
          final percentRaw = settingController.usagePercent();
          final percent = (percentRaw.isNaN ? 0.0 : percentRaw) / 100.0;
          final percentClamped = percent.clamp(0.0, 1.0);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.storage_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      (usageLabel.isNotEmpty && quotaLabel.isNotEmpty)
                          ? 'Storage: $usageLabel of $quotaLabel'
                          : 'Storage',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (!percentClamped.isNaN)
                    Text(
                      '${(percentClamped * 100).toStringAsFixed(0)}%',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.85),
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: percentClamped,
                  minHeight: 6,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  valueColor: AlwaysStoppedAnimation<Color>(
                    theme.colorScheme.secondary,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  'v1.0.0',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.55),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildComposeButton(BuildContext context) {
    return InkWell(
      onTap: () {
        ComposeModal.show(context);
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Iconsax.edit, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Text(
              'compose'.tr,
              style: const TextStyle(
                color: Colors.blue,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sort mailboxes by priority: Inbox, Sent, Drafts, Trash, Others
  List<Mailbox> _getSortedMailboxes(List<Mailbox> mailboxes) {
    final priorityOrder = {
      'inbox': 1,
      'sent': 2,
      'drafts': 3,
      'trash': 4,
      'spam': 5,
      'junk': 5,
      'flagged': 6,
    };

    return mailboxes.toList()..sort((a, b) {
      final priorityA = priorityOrder[a.name.toLowerCase()] ?? 999;
      final priorityB = priorityOrder[b.name.toLowerCase()] ?? 999;

      if (priorityA != priorityB) {
        return priorityA.compareTo(priorityB);
      }

      // If same priority, sort alphabetically
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
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
