import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/compose/compose_screen.dart';
import 'package:wahda_bank/views/view/screens/home/widgets/appbar.dart';
import 'package:wahda_bank/views/view/screens/home/widgets/mail_list.dart';
import 'package:wahda_bank/widgets/bottomnavs/selection_botttom_nav.dart';
import 'package:wahda_bank/widgets/drawer/drawer.dart';
import 'package:wahda_bank/widgets/progress_indicator_widget.dart';
import 'package:wahda_bank/widgets/t_animation_loader_widget.dart';
import 'package:enough_mail/enough_mail.dart';

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
              return TAnimationLoaderWidget(
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
                    List<MimeMessage> rows = messages.sorted((a, b) {
                      final dateA = a.decodeDate();
                      final dateB = b.decodeDate();
                      if (dateA == null && dateB == null) return 0;
                      if (dateA == null) return 1;
                      if (dateB == null) return -1;
                      return dateB.compareTo(dateA);
                    });

                    return MailList(
                      messages: rows,
                      onRefresh: () async {
                        await controller.loadEmailsForBox(controller.mailBoxInbox);
                      },
                    );
                  },
                ),
              ],
            );
          }),
          // Progress indicator overlay
          Obx(() {
            final progressController = Get.find<EmailDownloadProgressController>();
            return progressController.isVisible 
              ? EmailDownloadProgressWidget(
                  title: progressController.title,
                  subtitle: progressController.subtitle,
                ) 
              : const SizedBox.shrink();
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
          : Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Colors.grey.shade200),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.search,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Search in emails',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Container(
                    width: 1,
                    height: 24,
                    color: Colors.grey.shade300,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  Icon(
                    Icons.mic_none_rounded,
                    color: Colors.grey.shade600,
                    size: 20,
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

