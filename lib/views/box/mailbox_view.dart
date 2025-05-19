import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/email_fetch_controller.dart';
import 'package:wahda_bank/models/sqlite_mailbox_storage.dart';
import 'package:wahda_bank/utills/funtions.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../app/controllers/selection_controller.dart';
import '../../widgets/bottomnavs/selection_botttom_nav.dart';
import '../../widgets/empty_box.dart';
import '../../widgets/mail_tile.dart';
import '../view/showmessage/show_message.dart';
import '../../app/controllers/email_storage_controller.dart';

class MailBoxView extends GetView<EmailFetchController> {
  const MailBoxView({super.key, required this.mailBox});
  final Mailbox mailBox;

  @override
  Widget build(BuildContext context) {
    final selectionController = Get.find<SelectionController>();
    final storageController = Get.find<EmailStorageController>();

    // Ensure mailbox storage is initialized
    if (storageController.mailboxStorage[mailBox] == null) {
      // Initialize storage for this mailbox if not already done
      storageController.initializeMailboxStorage(mailBox);
    }

    return PopScope(
      onPopInvoked: (didPop) => selectionController.selected.clear(),
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
            // Use StreamBuilder instead of ValueListenableBuilder for SQLite
            child: StreamBuilder<List<MimeMessage>>(
              // Safely access the stream with null check
              stream: storageController.mailboxStorage[mailBox]?.messageStream,
              initialData: controller.emails[mailBox] ?? [],
              builder: (context, snapshot) {
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
                  itemCount: group.length,
                  itemBuilder: (context, index) {
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
                            return ModernMailTile(
                              onTap: () {
                                Get.to(
                                      () => ShowMessage(
                                    message: mail,
                                    mailbox: mailBox,
                                  ),
                                );
                              },
                              message: mail,
                              mailBox: mailBox,
                            );
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
            ),
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

  void _showMailboxOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(2),
                color: Colors.grey.shade300,
              ),
            ),
            Text(
              'mailbox_options'.tr,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
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
                // Mark all as read
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.purple.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.sort, color: Colors.purple),
              ),
              title: Text('sort_by'.tr),
              onTap: () {
                Get.back();
                // Show sort options
              },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.filter_list_outlined, color: Colors.amber),
              ),
              title: Text('filter_messages'.tr),
              onTap: () {
                Get.back();
                // Show filter options
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
}

class ModernMailTile extends StatelessWidget {
  final MimeMessage message;
  final Mailbox mailBox;
  final VoidCallback onTap;

  const ModernMailTile({
    Key? key,
    required this.message,
    required this.mailBox,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final selectionController = Get.find<SelectionController>();
    final from = message.from?.first;
    final subject = message.decodeSubject() ?? '';
    final preview = message.decodeTextPlainPart()?.substring(0,
        message.decodeTextPlainPart()!.length > 100
            ? 100
            : message.decodeTextPlainPart()!.length
    ) ?? '';
    final date = message.decodeDate() ?? DateTime.now();
    final hasAttachments = message.hasAttachments;
    final isUnread = !message.isSeen;

    // Get initials for avatar
    final nameInitials = from?.personalName != null && from!.personalName!.isNotEmpty
        ? from.personalName!.split(' ').take(2).map((e) => e[0]).join().toUpperCase()
        : from?.email.substring(0, 1).toUpperCase() ?? '?';

    // Get avatar color from palette
    final colorIndex = (nameInitials.codeUnitAt(0) % AppTheme.colorPalette.length);
    final avatarColor = AppTheme.colorPalette[colorIndex];

    return Obx(() {
      final isSelected = selectionController.selected.contains(message);

      return InkWell(
        onTap: selectionController.isSelecting
            ? () {
          if (isSelected) {
            selectionController.selected.remove(message);
          } else {
            selectionController.selected.add(message);
          }
        }
            : onTap,
        onLongPress: () {
          if (!selectionController.isSelecting) {
            selectionController.selected.add(message);
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          color: isSelected
              ? AppTheme.primaryColor.withOpacity(0.1)
              : isUnread
              ? AppTheme.unreadColor
              : Colors.transparent,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Selection indicator or avatar
              selectionController.isSelecting
                  ? Checkbox(
                value: isSelected,
                onChanged: (value) {
                  if (value == true) {
                    selectionController.selected.add(message);
                  } else {
                    selectionController.selected.remove(message);
                  }
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.smallBorderRadius / 2),
                ),
              )
                  : CircleAvatar(
                radius: 20,
                backgroundColor: avatarColor,
                child: Text(
                  nameInitials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 16),

              // Email content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Sender name
                        Expanded(
                          child: Text(
                            from?.personalName ?? from?.email ?? 'Unknown',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                              color: AppTheme.textPrimaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        // Date
                        Text(
                          _formatDate(date),
                          style: TextStyle(
                            fontSize: 12,
                            color: isUnread
                                ? AppTheme.textPrimaryColor
                                : AppTheme.textSecondaryColor,
                            fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    // Subject
                    Text(
                      subject,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isUnread ? FontWeight.w600 : FontWeight.normal,
                        color: isUnread
                            ? AppTheme.textPrimaryColor
                            : AppTheme.textSecondaryColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 4),

                    // Preview
                    Text(
                      preview,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.textTertiaryColor,
                        height: 1.4,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),

                    const SizedBox(height: 8),

                    // Indicators
                    Row(
                      children: [
            if (message.hasAttachments())
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.attachment,
                                  size: 14,
                                  color: AppTheme.primaryColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'attachment'.tr,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const Spacer(),
                        if (message.isFlagged)
                          Icon(
                            Icons.flag_rounded,
                            size: 16,
                            color: Colors.amber.shade700,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateDay = DateTime(date.year, date.month, date.day);

    if (dateDay == today) {
      return _formatTime(date);
    } else if (dateDay == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      return weekdays[date.weekday - 1];
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }

  String _formatTime(DateTime date) {
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
