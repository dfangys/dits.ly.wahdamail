import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/compose/redesigned_compose_screen.dart';
import 'package:wahda_bank/views/view/screens/home/widgets/appbar.dart';
import 'package:wahda_bank/widgets/bottomnavs/selection_botttom_nav.dart';
import 'package:wahda_bank/widgets/drawer/drawer.dart';
import 'package:wahda_bank/services/home_init_guard.dart';
import 'package:wahda_bank/views/view/screens/home/widgets/enhanced_home_email_list.dart';
import 'package:wahda_bank/views/box/enhanced_mailbox_view.dart' as boxview;

/// Enterprise-grade Home screen: initializes once, shows Gmail-like inbox list,
/// and keeps UI responsive while background sync and real-time updates run.
class HomeScreen extends GetView<MailBoxController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final selectionController = Get.find<SelectionController>();

    // One-time guarded initialization per app session.
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
      body: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          final isDark = theme.brightness == Brightness.dark;
          // Prefer mailbox-centric optimized view (backup baseline) for energy efficiency
return boxview.EnhancedMailboxLegacyView(
            mailbox: controller.mailBoxInbox,
            theme: theme,
            isDarkMode: isDark,
          );
        },
      ),
      floatingActionButton: Obx(
        () => selectionController.isSelecting
            ? const SizedBox.shrink()
            : FloatingActionButton(
                onPressed: () {
                  Get.to(() => const RedesignedComposeScreen());
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

