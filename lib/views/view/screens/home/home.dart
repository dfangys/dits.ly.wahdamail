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
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Center(
                  key: const ValueKey('home_loading'),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.primaryColor,
                        ),
                        strokeWidth: 3.0,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Loading your inbox...',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white70 
                              : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please wait while we fetch your messages',
                        style: TextStyle(
                          fontSize: 14,
                          color: Theme.of(context).brightness == Brightness.dark 
                              ? Colors.white54 
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
            
            return Stack(
              children: [
                Obx(() {
                  // CRITICAL FIX: Home screen should ALWAYS show inbox, not current mailbox
                  // This was the root cause - home screen was showing whatever mailbox user last visited
                  final storage = controller.mailboxStorage[controller.mailBoxInbox];
                  
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
                          // CRITICAL FIX: Always refresh inbox on home screen
                          await controller.refreshMailbox(controller.mailBoxInbox);
                        },
                        child: ListView.builder(
                          itemCount: rows.length,
                          itemBuilder: (context, index) {
                            return MailTile(
                              onTap: () {
                                // CRITICAL FIX: Always use inbox mailbox for home screen emails
                                final message = rows[index];
                                
                                // DEBUGGING: Log navigation attempt
                                print('=== HOME SCREEN EMAIL TAP DEBUG ===');
                                print('Subject: ${message.decodeSubject()}');
                                print('Mailbox: ${controller.mailBoxInbox.name} (ALWAYS INBOX)');
                                print('===================================');
                                
                                // Navigate to email detail view - always use inbox mailbox
                                Get.to(() => ShowMessage(
                                  message: message,
                                  mailbox: controller.mailBoxInbox,
                                ));
                              },
                              message: rows[index],
                              mailBox: controller.mailBoxInbox,
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

