import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/utills/funtions.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';
import 'package:wahda_bank/views/view/screens/home/widgets/appbar.dart';
import 'package:wahda_bank/widgets/bottomnavs/selection_botttom_nav.dart';
import 'package:wahda_bank/widgets/drawer/drawer.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';
import 'package:wahda_bank/widgets/search/search.dart';
import '../../../../app/controllers/selection_controller.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../widgets/empty_box.dart';
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
      body: Obx(
            () {
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

                  if (rows.isEmpty && !controller.isBoxBusy()) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.inbox_outlined,
                            size: 80,
                            color: Colors.grey.shade400,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Your inbox is empty',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey.shade600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Pull down to refresh',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  Map<DateTime, List<MimeMessage>> group = groupBy(
                    rows,
                        (MimeMessage msg) => filterDate(msg.decodeDate() ?? DateTime.now()),
                  );

                  return RefreshIndicator(
                    onRefresh: () async {
                      await controller.loadEmailsForBox(controller.mailBoxInbox);
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(top: 8, bottom: 16),
                      itemCount: group.length,
                      itemBuilder: (context, index) {
                        var item = group.entries.elementAt(index);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withValues(alpha : 0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              timeago.format(
                                item.value.isNotEmpty
                                    ? item.value.first.decodeDate() ?? DateTime.now()
                                    : DateTime.now(),
                              ),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),
                        ),
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, i) {
                            var mail = item.value.elementAt(i);
                            return Builder(builder: (context) {
                              return MailTile(
                                onTap: () {
                                  Get.to(
                                        () => ShowMessage(
                                      message: mail,
                                      mailbox: controller.mailBoxInbox,
                                    ),
                                  );
                                },
                                message: mail,
                                mailBox: controller.mailBoxInbox,
                              );
                            });
                          },
                          itemCount: item.value.length,
                        ),
                      ],
                    );
                  },
                ),
              );
            },
          ),
          // Loading overlay
          if (controller.isBoxBusy())
            Container(
              color: Colors.black.withValues(alpha: 0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
                ),
              ),
            ),
        ],
      );
        },
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
            () => AnimatedCrossFade(
          firstChild: const SizedBox(height: 0),
          secondChild: SelectionBottomNav(
            box: controller.mailBoxInbox,
          ),
          crossFadeState: selectionController.isSelecting
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 300),
        ),
      ),
    );
  }
}

class WSearchBar extends StatelessWidget {
  const WSearchBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        SearchController().clear();
        Get.to(
          SearchView(),
        );
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        height: 48,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha : 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(
                Icons.search,
                color: Colors.grey,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'search'.tr,
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 15,
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
