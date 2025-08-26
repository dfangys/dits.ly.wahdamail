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
import 'package:wahda_bank/views/box/mailbox_view.dart'; // Import for OptimizedEmailList

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
                  // Use the advanced OptimizedEmailList for inbox with all features
                  return OptimizedEmailList(
                    mailBox: controller.mailBoxInbox,
                    controller: controller,
                    theme: Theme.of(context),
                    isDarkMode: Theme.of(context).brightness == Brightness.dark,
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

