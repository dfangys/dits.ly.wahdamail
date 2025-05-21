import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/utills/funtions.dart';
import '../../app/controllers/mailbox_controller.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../app/controllers/selection_controller.dart';
import '../../widgets/bottomnavs/selection_botttom_nav.dart';
import '../../widgets/empty_box.dart';
import '../../widgets/mail_tile.dart';
import '../view/showmessage/show_message.dart';

class MailBoxView extends GetView<MailBoxController> {
  const MailBoxView({super.key, required this.mailBox});
  final Mailbox mailBox;

  @override
  Widget build(BuildContext context) {
    final selectionController = Get.find<SelectionController>();
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;

    return PopScope(
      onPopInvoked: (didPop) => selectionController.selected.clear(),
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            mailBox.name.toLowerCase().tr,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 20,
              color: theme.colorScheme.primary,
            ),
          ),
          centerTitle: true,
          elevation: 0,
          backgroundColor: isDarkMode
              ? Colors.black.withOpacity(0.7)
              : Colors.white.withOpacity(0.9),
          flexibleSpace: ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        body: RefreshIndicator(
          onRefresh: () async {
            await controller.loadEmailsForBox(mailBox);
          },
          color: theme.colorScheme.primary,
          backgroundColor: isDarkMode ? Colors.grey.shade900 : Colors.white,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDarkMode
                    ? [Colors.black, Colors.grey.shade900]
                    : [Colors.grey.shade50, Colors.white],
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
              child: ValueListenableBuilder<List<MimeMessage>>(
                valueListenable: controller.mailboxStorage[mailBox]!.dataNotifier,
                builder: (context, List<MimeMessage> messages, _) {
                  if (messages.isEmpty) {
                    return TAnimationLoaderWidget(
                      text: 'Whoops! Box is empty',
                      animation: 'assets/lottie/empty.json',
                      showAction: true,
                      actionText: 'try_again'.tr,
                      onActionPressed: () => controller.loadEmailsForBox(mailBox),
                    );
                  }

                  final sortedMessages = messages.sorted((a, b) {
                    final dateA = a.decodeDate() ?? DateTime(1970);
                    final dateB = b.decodeDate() ?? DateTime(1970);
                    return dateB.compareTo(dateA);
                  });

                  final grouped = groupBy<MimeMessage, DateTime>(
                    sortedMessages,
                        (m) => filterDate(m.decodeDate() ?? DateTime.now()),
                  );

                  return ListView.builder(
                    itemCount: grouped.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final item = grouped.entries.elementAt(index);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date header with modern styling
                          Container(
                            margin: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 8),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    timeago.format(item.value.first.decodeDate() ?? DateTime.now()),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: Divider(
                                    indent: 8,
                                    color: theme.colorScheme.primary.withOpacity(0.2),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          // Email list with animation
                          ListView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, i) {
                              final mail = item.value[i];
                              return AnimatedContainer(
                                duration: Duration(milliseconds: 300 + (i * 50)),
                                curve: Curves.easeOutQuad,
                                transform: Matrix4.translationValues(0, 0, 0),
                                child: MailTile(
                                  onTap: () {
                                    Get.to(() => ShowMessage(
                                      message: mail,
                                      mailbox: mailBox,
                                    ));
                                  },
                                  message: mail,
                                  mailBox: mailBox,
                                ),
                              );
                            },
                            itemCount: item.value.length,
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
        bottomNavigationBar: Obx(
              () => AnimatedCrossFade(
            firstChild: const SizedBox(),
            secondChild: Container(
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.black.withOpacity(0.9)
                    : Colors.white.withOpacity(0.9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: SelectionBottomNav(box: mailBox),
                ),
              ),
            ),
            crossFadeState: selectionController.isSelecting
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ),
        floatingActionButton: AnimatedOpacity(
          opacity: selectionController.isSelecting ? 0.0 : 1.0,
          duration: const Duration(milliseconds: 300),
          child: FloatingActionButton(
            onPressed: () => controller.loadEmailsForBox(mailBox),
            backgroundColor: theme.colorScheme.primary,
            child: const Icon(Icons.refresh, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
