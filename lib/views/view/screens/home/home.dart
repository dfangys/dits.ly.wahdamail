import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/compose/widgets/compose_modal.dart';
import 'package:wahda_bank/views/view/screens/home/widgets/appbar.dart';
import 'package:wahda_bank/views/box/enhanced_mailbox_view.dart';
import 'package:wahda_bank/widgets/bottomnavs/selection_botttom_nav.dart';
import 'package:wahda_bank/widgets/drawer/drawer.dart';
import 'package:wahda_bank/services/home_init_guard.dart';

class HomeScreen extends GetView<MailBoxController> {
  const HomeScreen({super.key});
  
  @override
  Widget build(BuildContext context) {
    final selectionController = Get.find<SelectionController>();
    
    // Initialize Home once per app session (single init guard)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      HomeInitGuard.instance.ensureInitialized(controller);
    });
    
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: appBar(),
      ),
      drawer: const Drawer1(),
      body: Obx(() {
        if (controller.isBusy()) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Loading inbox...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white70 
                        : Colors.grey.shade700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Please wait',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).brightness == Brightness.dark 
                        ? Colors.white54 
                        : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          );
        }
        
        // Use EnhancedMailboxView directly to avoid nested Scaffold and duplicate refresh/actions
        return EnhancedMailboxView(
          mailbox: controller.mailBoxInbox,
          theme: Theme.of(context),
          isDarkMode: Theme.of(context).brightness == Brightness.dark,
        );
      }),
      floatingActionButton: Obx(
        () => selectionController.isSelecting
          ? const SizedBox.shrink()
          : FloatingActionButton(
              onPressed: () {
                ComposeModal.show(context);
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

