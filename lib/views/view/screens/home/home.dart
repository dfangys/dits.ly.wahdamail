import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import 'package:wahda_bank/views/view/screens/home/widgets/appbar.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';
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
                Obx(() {
                  // CRITICAL FIX: Show current mailbox instead of hardcoded inbox
                  final currentMailbox = controller.currentMailbox ?? controller.mailBoxInbox;
                  final storage = controller.mailboxStorage[currentMailbox];
                  
                  if (storage == null) {
                    return const Center(
                      child: Text('Mailbox not initialized'),
                    );
                  }
                  
                  return ValueListenableBuilder<List<MimeMessage>>(
                    valueListenable: storage.dataNotifier,
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
                          // PERFORMANCE FIX: Use refreshMailbox for proper refresh
                          await controller.refreshMailbox(currentMailbox);
                        },
                        child: ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            return MailTile(
                              onTap: () {
                                // CRITICAL FIX: Route drafts to compose screen, regular emails to show message
                                final message = rows[index];
                                final isDraft = message.flags?.contains(MessageFlags.draft) ?? false;
                                
                                if (isDraft) {
                                  // Navigate to compose screen for draft editing
                                  Get.to(() => const ComposeScreen(), arguments: {
                                    'type': 'draft',
                                    'message': message,
                                  });
                                } else {
                                  // Navigate to email detail view for regular emails
                                  Get.to(() => ShowMessage(
                                    message: message,
                                    mailbox: currentMailbox,
                                  ));
                                }
                              },
                              message: rows[index],
                              mailBox: currentMailbox,
                            );
                          },
                        ),
                      );
                    },
                  );
                }),
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

