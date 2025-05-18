import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
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
import '../../../../models/hive_mime_storage.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../widgets/empty_box.dart';

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
          return ValueListenableBuilder<Box<StorageMessageEnvelope>>(
            valueListenable:
            controller.mailboxStorage[controller.mailBoxInbox]!.dataStream,
            builder: (context, box, child) {
              List<StorageMessageEnvelope> rows =
              box.values.sorted((a, b) => b.date!.compareTo(a.date!));

              if (rows.isEmpty) {
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

              Map<DateTime, List<StorageMessageEnvelope>> group = groupBy(
                rows,
                    (p) => filterDate(p.date ?? DateTime.now()),
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
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              timeago.format(
                                item.value.isNotEmpty
                                    ? item.value.first.date!
                                    : DateTime.now(),
                              ),
                              style: TextStyle(
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
                            var mail = item.value.elementAt(i).toMimeMessage();
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
              color: Colors.black.withOpacity(0.05),
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
