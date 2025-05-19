import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/email_fetch_controller.dart';
import 'package:wahda_bank/app/controllers/email_operation_controller.dart';
import 'package:wahda_bank/app/controllers/email_ui_state_controller.dart';
import 'package:wahda_bank/app/controllers/mailbox_list_controller.dart';
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
import '../../../../models/sqlite_mailbox_storage.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../../widgets/empty_box.dart';
import 'package:enough_mail/enough_mail.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Get all required controllers
    final fetchController = Get.find<EmailFetchController>();
    final operationController = Get.find<EmailOperationController>();
    final mailboxController = Get.find<MailboxListController>();
    final uiStateController = Get.find<EmailUIStateController>();
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
          if (uiStateController.isBusy()) {
            return TAnimationLoaderWidget(
              text: 'Searching for emails',
              animation: 'assets/lottie/search.json',
              showAction: false,
              actionText: 'try_again'.tr,
              onActionPressed: () {},
            );
          }

          // Use StreamBuilder with controller's emailsStream for real-time updates
          return StreamBuilder<Map<Mailbox, List<MimeMessage>>>(
            stream: fetchController.emailsStream,
            initialData: fetchController.emails,
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final mailboxEmails = snapshot.data![mailboxController.mailBoxInbox];
              if (mailboxEmails == null || mailboxEmails.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async {
                    // Use fetchNewEmails instead of loadEmailsForBox for incremental updates
                    await fetchController.fetchNewEmails(mailboxController.mailBoxInbox);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height - 100,
                        child: Center(
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
                        ),
                      ),
                    ],
                  ),
                );
              }

              // Group messages by date
              Map<DateTime, List<MimeMessage>> group = groupBy(
                mailboxEmails,
                    (MimeMessage m) => filterDate(m.decodeDate() ?? DateTime.now()),
              );

              return RefreshIndicator(
                onRefresh: () async {
                  // Use fetchNewEmails instead of loadEmailsForBox for incremental updates
                  await fetchController.fetchNewEmails(mailboxController.mailBoxInbox);
                },
                child: NotificationListener<ScrollNotification>(
                  // Add scroll listener to detect when user reaches bottom
                  onNotification: (ScrollNotification scrollInfo) {
                    if (scrollInfo is ScrollEndNotification &&
                        scrollInfo.metrics.pixels >= scrollInfo.metrics.maxScrollExtent * 0.9 &&
                        !uiStateController.isBoxBusy() &&
                        !uiStateController.isLoadingMore()) {
                      // Load more emails when user scrolls to bottom 90%
                      fetchController.loadMoreEmails(mailboxController.mailBoxInbox);
                    }
                    return false;
                  },
                  child: Stack(
                    children: [
                      ListView.builder(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.only(top: 8, bottom: 16),
                        itemCount: group.length + 1, // +1 for loading indicator
                        itemBuilder: (context, index) {
                          // Show loading indicator at the bottom when loading more
                          if (index == group.length) {
                            return Obx(() => uiStateController.isLoadingMore()
                                ? const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16.0),
                              child: Center(child: CircularProgressIndicator()),
                            )
                                : const SizedBox.shrink());
                          }

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
                                          ? item.value.first.decodeDate() ?? DateTime.now()
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
                                  var mail = item.value.elementAt(i);
                                  return Dismissible(
                                    key: ValueKey('mail_${mail.uid}'),
                                    background: Container(
                                      color: Colors.red,
                                      alignment: Alignment.centerRight,
                                      padding: const EdgeInsets.only(right: 20),
                                      child: const Icon(
                                        Icons.delete,
                                        color: Colors.white,
                                      ),
                                    ),
                                    direction: DismissDirection.endToStart,
                                    confirmDismiss: (direction) async {
                                      return await showDialog(
                                        context: context,
                                        builder: (BuildContext context) {
                                          return AlertDialog(
                                            title: const Text("Confirm"),
                                            content: const Text("Are you sure you want to delete this email?"),
                                            actions: [
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(false),
                                                child: const Text("CANCEL"),
                                              ),
                                              TextButton(
                                                onPressed: () => Navigator.of(context).pop(true),
                                                child: const Text("DELETE"),
                                              ),
                                            ],
                                          );
                                        },
                                      );
                                    },
                                    onDismissed: (direction) {
                                      // Use optimistic UI update for deletion
                                      operationController.deleteMails([mail], mailboxController.mailBoxInbox);
                                    },
                                    child: Builder(builder: (context) {
                                      return MailTile(
                                        onTap: () {
                                          // Mark as seen with optimistic UI update when opening
                                          if (!mail.isSeen) {
                                            operationController.markAsReadUnread(
                                                [mail],
                                                mailboxController.mailBoxInbox,
                                                true
                                            );
                                          }

                                          Get.to(
                                                () => ShowMessage(
                                              message: mail,
                                              mailbox: mailboxController.mailBoxInbox,
                                            ),
                                          );
                                        },
                                        message: mail,
                                        mailBox: mailboxController.mailBoxInbox,
                                        // Add long press handler for flagging
                                        onLongPress: () {
                                          operationController.updateFlag(
                                              [mail],
                                              mailboxController.mailBoxInbox
                                          );
                                        },
                                      );
                                    }),
                                  );
                                },
                                itemCount: item.value.length,
                              ),
                            ],
                          );
                        },
                      ),
                      // Overlay a progress indicator when refreshing
                      Obx(() => uiStateController.isRefreshing() && !uiStateController.isBoxBusy()
                          ? Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          height: 2,
                          child: const LinearProgressIndicator(),
                        ),
                      )
                          : const SizedBox.shrink()),
                    ],
                  ),
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
            box: mailboxController.mailBoxInbox,
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
