import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
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
      backgroundColor: AppTheme.cardDesignColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(50),
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
              Map<DateTime, List<StorageMessageEnvelope>> group = groupBy(
                rows,
                (p) {
                  var dt = p.date ?? DateTime.now();
                  return DateTime(dt.year, dt.month);
                },
              );
              return RefreshIndicator(
                onRefresh: () async {
                  await controller.loadEmailsForBox(controller.mailBoxInbox);
                },
                child: ListView.builder(
                  itemCount: group.length,
                  itemBuilder: (context, index) {
                    var item = group.entries.elementAt(index);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Text(
                            timeago.format(
                              item.value.isNotEmpty
                                  ? item.value.first.date!
                                  : DateTime.now(),
                            ),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                        ),
                        ListView.separated(
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
                          separatorBuilder: (context, i) => Divider(
                            color: Colors.grey.shade300,
                            height: 0,
                          ),
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
      bottomNavigationBar: Obx(
        () => AnimatedCrossFade(
          firstChild: const SizedBox(),
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
        margin: const EdgeInsets.only(top: 2, left: 10, right: 10),
        height: 40,
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          color: Colors.grey.shade300,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            children: [
              Text(
                'search'.tr,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const Spacer(),
              Container(
                width: 1,
                height: 20,
                color: Colors.grey.shade400,
                margin: const EdgeInsets.symmetric(horizontal: 5),
              ),
              GestureDetector(
                onTap: () {},
                child: const Icon(
                  Icons.search,
                  color: Colors.black,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
