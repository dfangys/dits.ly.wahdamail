import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/email_fetch_controller.dart';
import 'package:wahda_bank/app/controllers/email_operation_controller.dart';
import 'package:wahda_bank/app/controllers/email_storage_controller.dart';
import 'package:wahda_bank/app/controllers/email_ui_state_controller.dart';
import 'package:wahda_bank/models/sqlite_mailbox_storage.dart';
import 'package:wahda_bank/utills/funtions.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../app/controllers/selection_controller.dart';
import '../../widgets/bottomnavs/selection_botttom_nav.dart';
import '../../widgets/empty_box.dart';
import '../../widgets/mail_tile.dart';
import '../view/showmessage/show_message.dart';

class MailBoxView extends GetView<EmailFetchController> {
  const MailBoxView({super.key, required this.mailBox});
  final Mailbox mailBox;

  @override
  Widget build(BuildContext context) {
    final selectionController = Get.find<SelectionController>();
    final storageController = Get.find<EmailStorageController>();
    final UIStateController = Get.find<EmailUiStateController>();
    final operationController = Get.find<EmailOperationController>();

    // Ensure mailbox storage is initialized
    if (storageController.mailboxStorage[mailBox] == null) {
      // Initialize storage for this mailbox if not already done
      storageController.initializeMailboxStorage(mailBox);

    }

    // Set current mailbox in UI state controller
    UIStateController.setCurrentMailbox(mailBox);

    return PopScope(
      onPopInvoked: (didPop) {
        selectionController.selected.clear();
        UIStateController.clearCurrentMailbox();
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 0,
          scrolledUnderElevation: 2,
          title: Text(
            mailBox.name.toLowerCase().tr,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.search_rounded),
              onPressed: () {
                // Search functionality
                _showSearchDialog(context);
              },
            ),
            Obx(() => IconButton(
              icon: Icon(
                selectionController.isSelecting
                    ? Icons.close_rounded
                    : Icons.more_vert_rounded,
              ),
              onPressed: () {
                if (selectionController.isSelecting) {
                  selectionController.selected.clear();
                } else {
                  // Show more options
                  _showMailboxOptions(context);
                }
              },
            )),
          ],
        ),
        body: RefreshIndicator(
          color: AppTheme.primaryColor,
          backgroundColor: AppTheme.surfaceColor,
          onRefresh: () async {
            await controller.loadEmailsForBox(mailBox);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            // Use Obx for reactive UI updates
            child: Obx(() {
              // Show connection error if not connected
              if (!UIStateController.isConnected.value && !controller.isBoxBusy.value) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.cloud_off,
                        color: Colors.grey,
                        size: 48,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No connection to mail server',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Showing cached messages',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () {
                          controller.loadEmailsForBox(mailBox);
                        },
                        child: Text('Try Again'.tr),
                      ),
                    ],
                  ),
                );
              }

              // Use StreamBuilder for SQLite updates
              return StreamBuilder<List<MimeMessage>>(
                // Safely access the stream with null check
                stream: storageController.mailboxStorage[mailBox]?.messageStream,
                initialData: controller.emails[mailBox] ?? [],
                builder: (context, snapshot) {
                  // Show loading indicator when busy
                  if (controller.isBoxBusy.value) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    );
                  }

                  // Handle error state
                  if (snapshot.hasError) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            color: Colors.red,
                            size: 48,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Error loading messages',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton(
                            onPressed: () {
                              controller.loadEmailsForBox(mailBox);
                            },
                            child: Text('Try Again'.tr),
                          ),
                        ],
                      ),
                    );
                  }

                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppTheme.primaryColor,
                      ),
                    );
                  }

                  List<MimeMessage> messages = snapshot.data!;

                  if (messages.isEmpty) {
                    return TAnimationLoaderWidget(
                      text: 'Whoops! Box is empty',
                      animation: 'assets/lottie/empty.json',
                      showAction: true,
                      actionText: 'try_again'.tr,
                      onActionPressed: () {
                        controller.loadEmailsForBox(mailBox);
                      },
                    );
                  }

                  // Apply filters if active
                  if (UIStateController.isFilterActive) {
                    final filter = UIStateController.currentFilter.value;

                    if (filter.onlyUnread) {
                      messages = messages.where((msg) => !msg.isSeen).toList();
                    }

                    if (filter.onlyFlagged) {
                      messages = messages.where((msg) => msg.isFlagged).toList();
                    }

                    if (filter.onlyWithAttachments) {
                      messages = messages.where((msg) => msg.hasAttachments()).toList();
                    }

                    if (filter.fromDate != null) {
                      messages = messages.where((msg) {
                        final date = msg.decodeDate();
                        return date != null && date.isAfter(filter.fromDate!);
                      }).toList();
                    }

                    if (filter.toDate != null) {
                      messages = messages.where((msg) {
                        final date = msg.decodeDate();
                        return date != null && date.isBefore(filter.toDate!);
                      }).toList();
                    }

                    if (filter.searchTerm.isNotEmpty) {
                      final term = filter.searchTerm.toLowerCase();
                      messages = messages.where((msg) {
                        final subject = msg.decodeSubject()?.toLowerCase() ?? '';
                        final from = msg.fromEmail?.toLowerCase() ?? '';
                        return subject.contains(term) || from.contains(term);
                      }).toList();
                    }

                    // Show empty state if filtered list is empty
                    if (messages.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.filter_list,
                              color: Colors.grey,
                              size: 48,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No messages match your filters',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 16),
                            ElevatedButton(
                              onPressed: () {
                                UIStateController.clearFilter();
                              },
                              child: Text('Clear Filters'.tr),
                            ),
                          ],
                        ),
                      );
                    }
                  }

                  // Sort messages by date
                  messages.sort((a, b) {
                    final dateA = a.decodeDate() ?? DateTime.now();
                    final dateB = b.decodeDate() ?? DateTime.now();
                    return dateB.compareTo(dateA);
                  });

                  // Group messages by date
                  Map<DateTime, List<MimeMessage>> group = groupBy(
                    messages,
                        (MimeMessage m) => filterDate(m.decodeDate() ?? DateTime.now()),
                  );

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics(),
                    ),
                    itemCount: group.length + 1, // +1 for load more button
                    itemBuilder: (context, index) {
                      // Add load more button at the end
                      if (index == group.length) {
                        return Obx(() => controller.isLoadingMore.value
                            ? const Center(
                          child: Padding(
                            padding: EdgeInsets.all(16.0),
                            child: CircularProgressIndicator(
                              color: AppTheme.primaryColor,
                            ),
                          ),
                        )
                            : Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: ElevatedButton(
                            onPressed: () {
                              controller.loadMoreEmails(mailBox);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primaryColor,
                              foregroundColor: Colors.white,
                            ),
                            child: Text('Load More'.tr),
                          ),
                        ));
                      }

                      var item = group.entries.elementAt(index);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                                left: 20,
                                right: 20,
                                top: 16,
                                bottom: 8
                            ),
                            child: Text(
                              timeago.format(
                                item.value.isNotEmpty
                                    ? item.value.first.decodeDate() ?? DateTime.now()
                                    : DateTime.now(),
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Theme.of(context).primaryColor,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ),
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemBuilder: (context, i) {
                              var mail = item.value.elementAt(i);
                              return Obx(() {
                                final isSelected = selectionController.isSelected(mail);
                                return MailTile(
                                  onTap: () {
                                    if (selectionController.isSelecting) {
                                      selectionController.toggleSelection(mail);
                                    } else {
                                      // Mark as seen when opening
                                      if (!mail.isSeen) {
                                        operationController.markMessageAsSeen(mail, mailBox);
                                      }

                                      // Open message
                                      _openMessage(mail, storageController);
                                    }
                                  },
                                  onLongPress: () {
                                    selectionController.toggleSelection(mail);
                                  },
                                  message: mail,
                                  mailBox: mailBox,
                                );
                              });
                            },
                            separatorBuilder: (context, i) => const Divider(
                              color: AppTheme.dividerColor,
                              height: 1,
                              indent: 72,
                            ),
                            itemCount: item.value.length,
                          ),
                          if (index < group.length - 1)
                            const Divider(
                              color: AppTheme.dividerColor,
                              height: 1,
                            ),
                        ],
                      );
                    },
                  );
                },
              );
            }),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: AppTheme.primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 2,
          onPressed: () {
            // Navigate to compose screen
            Get.toNamed('/compose');
          },
          child: const Icon(
            Icons.edit_outlined,
            color: Colors.white,
          ),
        ),
        bottomNavigationBar: Obx(
              () => AnimatedCrossFade(
            firstChild: const SizedBox(height: 0),
            secondChild: SelectionBottomNav(
              box: mailBox,
            ),
            crossFadeState: selectionController.isSelecting
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 300),
          ),
        ),
      ),
    );
  }

  // Improved message opening with error handling
  void _openMessage(MimeMessage mail, EmailStorageController storageController) async {
    try {
      // Show loading indicator
      Get.dialog(
        const Center(
          child: CircularProgressIndicator(
            color: AppTheme.primaryColor,
          ),
        ),
        barrierDismissible: false,
      );

      // Fetch full message content if needed
      final fullMessage = await storageController.fetchMessageContents(mail, mailBox);


      // Close loading dialog
      Get.back();

      // Navigate to message view
      Get.to(() => ShowMessage(
        message: fullMessage ?? mail,
        mailbox: mailBox,
      ));
    } catch (e) {
      // Close loading dialog
      Get.back();

      // Show error
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error opening message: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Show mailbox options
  void _showMailboxOptions(BuildContext context) {
    final uiStateController = Get.find<EmailUiStateController>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(20),
        ),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.mark_email_read_outlined, color: Colors.blue),
              ),
              title: Text('mark_all_read'.tr),
              onTap: () {
                Get.back();
                _markAllAsRead();
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.refresh_outlined, color: Colors.green),
              ),
              title: Text('refresh'.tr),
              onTap: () {
                Get.back();
                controller.loadEmailsForBox(mailBox);
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                    uiStateController.isFilterActive
                        ? Icons.filter_list_off_outlined
                        : Icons.filter_list_outlined,
                    color: Colors.amber
                ),
              ),
              title: Text(
                  uiStateController.isFilterActive
                      ? 'clear_filters'.tr
                      : 'filter_messages'.tr
              ),
              onTap: () {
                Get.back();
                if (uiStateController.isFilterActive) {
                  uiStateController.clearFilter();
                } else {
                  _showFilterDialog(context);
                }
              },
            ),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ElevatedButton(
                onPressed: () => Get.back(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey.shade200,
                  foregroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text('cancel'.tr),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Mark all messages as read
  void _markAllAsRead() async {
    final storageController = Get.find<EmailStorageController>();
    final operationController = Get.find<EmailOperationController>();
    final messages = controller.emails[mailBox] ?? [];

    if (messages.isEmpty) return;

    // Find unread messages
    final unreadMessages = messages.where((msg) => !msg.isSeen).toList();

    if (unreadMessages.isEmpty) {
      Get.showSnackbar(
        GetSnackBar(
          message: 'All messages are already read',
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
      return;
    }

    // Show loading indicator
    Get.dialog(
      const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
        ),
      ),
      barrierDismissible: false,
    );

    try {
      // Mark messages as read
      await operationController.markMessagesAsSeen(unreadMessages, mailBox);

      // Close loading dialog
      Get.back();

      // Show success message
      Get.showSnackbar(
        GetSnackBar(
          message: 'Marked ${unreadMessages.length} messages as read',
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 3),
        ),
      );
    } catch (e) {
      // Close loading dialog
      Get.back();

      // Show error
      Get.showSnackbar(
        GetSnackBar(
          message: 'Error marking messages as read: ${e.toString()}',
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Show search dialog
  void _showSearchDialog(BuildContext context) {
    final uiStateController = Get.find<EmailUiStateController>();
    final searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Search Messages'.tr),
        content: TextField(
          controller: searchController,
          decoration: InputDecoration(
            hintText: 'Enter search term'.tr,
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('Cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              if (searchController.text.isNotEmpty) {
                uiStateController.search(searchController.text);
              }
              Get.back();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Search'.tr),
          ),
        ],
      ),
    );
  }

  // Show filter dialog
  void _showFilterDialog(BuildContext context) {
    final uiStateController = Get.find<EmailUiStateController>();

    // Create temporary filter
    final filter = MessageFilter(
      onlyUnread: uiStateController.currentFilter.value.onlyUnread,
      onlyFlagged: uiStateController.currentFilter.value.onlyFlagged,
      onlyWithAttachments: uiStateController.currentFilter.value.onlyWithAttachments,
      fromDate: uiStateController.currentFilter.value.fromDate,
      toDate: uiStateController.currentFilter.value.toDate,
      searchTerm: uiStateController.currentFilter.value.searchTerm,
    );

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text('Filter Messages'.tr),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  title: Text('Only Unread'.tr),
                  value: filter.onlyUnread,
                  onChanged: (value) {
                    setState(() {
                      filter.onlyUnread = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: Text('Only Flagged'.tr),
                  value: filter.onlyFlagged,
                  onChanged: (value) {
                    setState(() {
                      filter.onlyFlagged = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                CheckboxListTile(
                  title: Text('With Attachments'.tr),
                  value: filter.onlyWithAttachments,
                  onChanged: (value) {
                    setState(() {
                      filter.onlyWithAttachments = value ?? false;
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                ),
                const SizedBox(height: 16),
                Text(
                  'Date Range'.tr,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          filter.fromDate != null
                              ? '${filter.fromDate!.day}/${filter.fromDate!.month}/${filter.fromDate!.year}'
                              : 'From Date'.tr,
                        ),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: filter.fromDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              filter.fromDate = date;
                            });
                          }
                        },
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        icon: const Icon(Icons.calendar_today),
                        label: Text(
                          filter.toDate != null
                              ? '${filter.toDate!.day}/${filter.toDate!.month}/${filter.toDate!.year}'
                              : 'To Date'.tr,
                        ),
                        onPressed: () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: filter.toDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (date != null) {
                            setState(() {
                              filter.toDate = date;
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Get.back(),
              child: Text('Cancel'.tr),
            ),
            ElevatedButton(
              onPressed: () {
                uiStateController.setFilter(filter);
                Get.back();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: Text('Apply'.tr),
            ),
          ],
        ),
      ),
    );
  }
}

// Message filter class
class MessageFilter {
  bool onlyUnread;
  bool onlyFlagged;
  bool onlyWithAttachments;
  DateTime? fromDate;
  DateTime? toDate;
  String searchTerm;

  MessageFilter({
    this.onlyUnread = false,
    this.onlyFlagged = false,
    this.onlyWithAttachments = false,
    this.fromDate,
    this.toDate,
    this.searchTerm = '',
  });

  bool get isEmpty =>
      !onlyUnread &&
          !onlyFlagged &&
          !onlyWithAttachments &&
          fromDate == null &&
          toDate == null &&
          searchTerm.isEmpty;
}
