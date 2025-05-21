import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/email_fetch_controller.dart';
import 'package:wahda_bank/app/controllers/email_operation_controller.dart';
import 'package:wahda_bank/app/controllers/email_storage_controller.dart';
import 'package:wahda_bank/app/controllers/email_ui_state_controller.dart';
import 'package:wahda_bank/app/controllers/mailbox_list_controller.dart';
import 'package:wahda_bank/services/mail_service.dart';
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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  // Get all required controllers
  final EmailFetchController fetchController = Get.find<EmailFetchController>();
  final EmailOperationController operationController = Get.find<EmailOperationController>();
  final MailboxListController mailboxController = Get.find<MailboxListController>();
  final EmailUiStateController uiStateController = Get.find<EmailUiStateController>();
  final SelectionController selectionController = Get.find<SelectionController>();
  final MailService mailService = MailService.instance;

  final ScrollController _scrollController = ScrollController();
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize UI state
    uiStateController.setCurrentView(ViewType.inbox);

    // Initialize inbox
    _initializeInbox();

    // Add scroll listener for pagination
    _scrollController.addListener(_scrollListener);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      _isInitialized = true;
      // Fetch emails after first build
      _fetchEmails();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Reconnect and refresh when app comes to foreground
    if (state == AppLifecycleState.resumed) {
      if (!mailService.isConnected) {
        mailService.connect().then((connected) {
          if (connected) {
            _fetchEmails();
          }
        });
      } else {
        _fetchEmails();
      }
    }
  }

  // Initialize inbox
  Future<void> _initializeInbox() async {
    try {
      if (mailboxController.mailBoxInbox == null) {
        await mailboxController.loadMailBoxes();
      }
      final inbox = mailboxController.mailBoxInbox;
      if (inbox != null) {
        // this will do initializeMailboxStorage + pull from server
        await fetchController.loadEmailsForBox(inbox);
      }
    } catch (e) {
      debugPrint('Error initializing inbox: $e');
    }
  }

  // Fetch emails
  Future<void> _fetchEmails() async {
    if (mailboxController.mailBoxInbox != null) {
      await fetchController.fetchNewEmails(mailboxController.mailBoxInbox!);
    }
  }

  // Scroll listener for pagination
  void _scrollListener() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent * 0.9 &&
        !uiStateController.isBoxBusy.value &&
        !uiStateController.isLoadingMore.value &&
        mailboxController.mailBoxInbox != null) {
      // Load more emails when user scrolls to bottom 90%
      fetchController.loadMoreEmails(mailboxController.mailBoxInbox!);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: appBar(),
      ),
      drawer: const Drawer1(),
      body: Obx(() {
        // Show loading state
        if (uiStateController.isBoxBusy.value && fetchController.emails.isEmpty) {
          return TAnimationLoaderWidget(
            text: 'Loading your emails',
            animation: 'assets/lottie/search.json',
            showAction: false,
            actionText: 'try_again'.tr,
            onActionPressed: () {},
          );
        }

        // Show connection error if not connected
        if (!uiStateController.isConnected.value && !uiStateController.isBoxBusy.value) {
          return RefreshIndicator(
            onRefresh: _fetchEmails,
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
                          Icons.cloud_off,
                          size: 80,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No connection to mail server',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Showing cached emails',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade500,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: () {
                            mailService.connect().then((connected) {
                              if (connected && mailboxController.mailBoxInbox != null) {
                                fetchController.loadEmailsForBox(mailboxController.mailBoxInbox!);
                              }
                            });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Try Again'.tr),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Use StreamBuilder with controller's emailsMapStream for reactive updates
        return StreamBuilder<Map<Mailbox, List<MimeMessage>>>(
          stream: fetchController.emailsMapStream,
          initialData: fetchController.emails,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final mailboxEmails = mailboxController.mailBoxInbox != null
                ? snapshot.data![mailboxController.mailBoxInbox]
                : null;

            if (mailboxEmails == null || mailboxEmails.isEmpty) {
              return RefreshIndicator(
                onRefresh: _fetchEmails,
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

            // Apply filters if active
            List<MimeMessage> filteredEmails = mailboxEmails;
            if (uiStateController.isFilterActive) {
              final filter = uiStateController.currentFilter.value;

              if (filter.onlyUnread) {
                filteredEmails = filteredEmails.where((msg) => !msg.isSeen).toList();
              }

              if (filter.onlyFlagged) {
                filteredEmails = filteredEmails.where((msg) => msg.isFlagged).toList();
              }

              if (filter.onlyWithAttachments) {
                filteredEmails = filteredEmails.where((msg) => msg.hasAttachments()).toList();
              }

              if (filter.fromDate != null) {
                filteredEmails = filteredEmails.where((msg) {
                  final date = msg.decodeDate();
                  return date != null && date.isAfter(filter.fromDate!);
                }).toList();
              }

              if (filter.toDate != null) {
                filteredEmails = filteredEmails.where((msg) {
                  final date = msg.decodeDate();
                  return date != null && date.isBefore(filter.toDate!);
                }).toList();
              }

              if (filter.searchTerm.isNotEmpty) {
                final term = filter.searchTerm.toLowerCase();
                filteredEmails = filteredEmails.where((msg) {
                  final subject = msg.decodeSubject()?.toLowerCase() ?? '';
                  final from = msg.fromEmail?.toLowerCase() ?? '';
                  return subject.contains(term) || from.contains(term);
                }).toList();
              }

              // Show empty state if filtered list is empty
              if (filteredEmails.isEmpty) {
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
                          uiStateController.clearFilter();
                        },
                        child: Text('Clear Filters'.tr),
                      ),
                    ],
                  ),
                );
              }
            }

            // Group messages by date
            Map<DateTime, List<MimeMessage>> group = groupBy(
              filteredEmails,
                  (MimeMessage m) => filterDate(m.decodeDate() ?? DateTime.now()),
            );

            return RefreshIndicator(
              onRefresh: _fetchEmails,
              child: Stack(
                children: [
                  ListView.builder(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(top: 8, bottom: 16),
                    itemCount: group.length + 1, // +1 for loading indicator
                    itemBuilder: (context, index) {
                      // Show loading indicator at the bottom when loading more
                      if (index == group.length) {
                        return Obx(() => uiStateController.isLoadingMore.value
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
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: item.value.length,
                            itemBuilder: (context, i) {
                              final mail = item.value[i];
                              return Dismissible(
                                key: ValueKey('mail_${mail.uid ?? mail.sequenceId ?? i}'),
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
                                  return await Get.dialog<bool>(
                                    AlertDialog(
                                      title: Text('delete_email'.tr),
                                      content: Text('confirm_delete_email'.tr),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Get.back(result: false),
                                          child: Text('cancel'.tr),
                                        ),
                                        ElevatedButton(
                                          onPressed: () => Get.back(result: true),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: AppTheme.errorColor,
                                            foregroundColor: Colors.white,
                                          ),
                                          child: Text('delete'.tr),
                                        ),
                                      ],
                                    ),
                                  ) ??
                                      false;
                                },
                                onDismissed: (direction) {
                                  if (mailboxController.mailBoxInbox != null) {
                                    operationController.moveToTrash(
                                      [mail],
                                      mailboxController.mailBoxInbox!,
                                    );
                                  }
                                },
                                child: MailTile(
                                  message: mail,
                                  mailBox: mailboxController.mailBoxInbox!,
                                  onTap: () {
                                    Get.to(
                                          () => ShowMessage(
                                        message: mail,
                                        mailbox: mailboxController.mailBoxInbox!,
                                      ),
                                    );
                                  },
                                  onLongPress: () {
                                    selectionController.toggleSelection(mail);
                                  },
                                ),
                              );
                            },
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              indent: 72,
                              color: AppTheme.dividerColor,
                            ),
                          ),                          if (index < group.length - 1)
                            const Divider(
                              height: 1,
                              color: AppTheme.dividerColor,
                            ),
                        ],
                      );
                    },
                  ),

                  // Show selection bottom bar when items are selected
                  Obx(() => selectionController.selectedItems.isNotEmpty
                      ? Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child:
                    SelectionBottomNav(
                      box: mailboxController.mailBoxInbox!,
                    ),
                  )
                      : const SizedBox.shrink()),
                ],
              ),
            );
          },
        );
      }),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppTheme.primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        elevation: 2,
        onPressed: () {
          Get.to(() => const ComposeScreen());
        },
        child: const Icon(
          Icons.edit_outlined,
          color: Colors.white,
        ),
        tooltip: 'compose_new'.tr,
      ),
    );
  }

  // Confirm delete selected messages
  void _confirmDeleteSelected() {
    Get.dialog(
      AlertDialog(
        title: Text('delete_selected'.tr),
        content: Text(
          'confirm_delete_selected'.trParams({
            'count': selectionController.selectedItems.length.toString(),
          }),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('cancel'.tr),
          ),
          ElevatedButton(
            onPressed: () {
              Get.back();
              _deleteSelected();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.errorColor,
              foregroundColor: Colors.white,
            ),
            child: Text('delete'.tr),
          ),
        ],
      ),
    );
  }

  // Delete selected messages
  void _deleteSelected() {
    if (mailboxController.mailBoxInbox != null) {
      operationController.moveMessagesToTrash(
        selectionController.selectedItems,
        mailboxController.mailBoxInbox!,
      );
      selectionController.clearSelection();
    }
  }

  // Mark selected messages as read/unread
  void _markSelectedAsRead(bool asRead) {
    if (mailboxController.mailBoxInbox != null) {
      operationController.markAsReadUnread(
        selectionController.selectedItems,
        mailboxController.mailBoxInbox!,
        asRead,

      );
      selectionController.clearSelection();
    }
  }

  // Flag/unflag selected messages
  void _flagSelected(bool asFlagged) {
    if (mailboxController.mailBoxInbox != null) {
      operationController.updateFlag(
        selectionController.selectedItems,
        mailboxController.mailBoxInbox!,
      );
      selectionController.clearSelection();
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_scrollListener);
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
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
            ],
          ),
        ),
      ),
    );
  }
}
