import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import 'package:wahda_bank/views/view/screens/home/widgets/appbar.dart';
import 'package:wahda_bank/widgets/bottomnavs/selection_botttom_nav.dart';
import 'package:wahda_bank/widgets/drawer/drawer.dart';
import 'package:wahda_bank/widgets/progress_indicator_widget.dart';
import 'package:wahda_bank/utills/loaders/animation_loader.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';

class HomeScreen extends GetView<MailBoxController> {
  const HomeScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    final selectionController = Get.find<SelectionController>();
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: appBar(),
      ),
      drawer: const Drawer1(),
      body: Stack(
        children: [
          Obx(() {
            if (controller.isBusy()) {
              return WAnimationLoaderWidget(
                text: 'Searching for emails',
                animation: 'assets/lottie/search.json',
                showAction: false,
                actionText: 'try_again'.tr,
                onActionPressed: () {},
              );
            }
            
            return Stack(
              children: [
                ValueListenableBuilder<List<MimeMessage>>(
                  valueListenable: controller.mailboxStorage[controller.mailBoxInbox]!.dataNotifier,
                  builder: (context, messages, child) {
                    List<MimeMessage> rows = messages.toList()..sort((a, b) {
                      final dateA = a.decodeDate();
                      final dateB = b.decodeDate();
                      if (dateA == null && dateB == null) return 0;
                      if (dateA == null) return 1;
                      if (dateB == null) return -1;
                      return dateB.compareTo(dateA);
                    });

                    return RefreshIndicator(
                      onRefresh: () async {
                        await controller.loadEmailsForBox(controller.mailBoxInbox);
                      },
                      child: ListView.builder(
                        itemCount: rows.length,
                        itemBuilder: (context, index) {
                          return MailTile(
                            onTap: () {
                              // Handle email tap - navigate to email detail view
                            },
                            message: rows[index],
                            mailBox: controller.mailBoxInbox,
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            );
          }),
          // Progress indicator overlay
          Obx(() {
            try {
              final progressController = Get.find<EmailDownloadProgressController>();
              return progressController.isVisible 
                ? EmailDownloadProgressWidget(
                    title: progressController.title,
                    subtitle: progressController.subtitle,
                  ) 
                : const SizedBox.shrink();
            } catch (e) {
              // Controller not found, return empty widget
              return const SizedBox.shrink();
            }
          }),
        ],
      ),
      floatingActionButton: Obx(
        () => selectionController.isSelecting
          ? const SizedBox.shrink()
          : FloatingActionButton(
              onPressed: () {
                Get.to(() => const ComposeScreen());
              },
              backgroundColor: AppTheme.primaryColor,
              child: const Icon(Icons.edit_outlined, color: Colors.white),
            ),
      ),
      bottomNavigationBar: Obx(
        () => selectionController.isSelecting
          ? SelectionBottomNav(box: controller.mailBoxInbox)
          : const SizedBox.shrink(),
      ),
    );
  }
}

