import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wahda_bank/models/hive_mime_storage.dart';
import 'package:wahda_bank/utills/funtions.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import '../../app/controllers/mailbox_controller.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../app/controllers/selection_controller.dart';
import '../../widgets/bottomnavs/selection_botttom_nav.dart';
import '../../widgets/empty_box.dart';
import '../../widgets/mail_tile.dart';
import '../view/showmessage/show_message.dart';
import 'package:wahda_bank/utills/extensions/mailbox_controller_extensions.dart';

class MailboxView extends GetView<MailBoxController> {
  const MailboxView({super.key, required this.mailBox});
  final Mailbox mailBox;

  @override
  Widget build(BuildContext context) {
    final selectionController = Get.find<SelectionController>();
    return PopScope(
      onPopInvoked: (didPop) => selectionController.selected.clear(),
      child: Scaffold(
        backgroundColor: AppTheme.backgroundColor,
        appBar: AppBar(
          title: Text(
            mailBox.name.toLowerCase().tr,
            style: TextStyle(
              color: AppTheme.textPrimaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          backgroundColor: AppTheme.surfaceColor,
          elevation: 0,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              bottom: Radius.circular(16),
            ),
          ),
          actions: [
            IconButton(
              icon: Icon(
                Icons.search_rounded,
                color: AppTheme.primaryColor,
              ),
              onPressed: () {
                // Navigate to search with current mailbox context
                Get.toNamed('/search', arguments: {'mailbox': mailBox});
              },
            ),
            IconButton(
              icon: Icon(
                Icons.more_vert_rounded,
                color: AppTheme.primaryColor,
              ),
              onPressed: () {
                _showMailboxOptions(context);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: RefreshIndicator(
            color: AppTheme.primaryColor,
            backgroundColor: AppTheme.surfaceColor,
            strokeWidth: 2,
            onRefresh: () async {
              await controller.loadEmailsForBox(mailBox);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: ValueListenableBuilder<Box<StorageMessageEnvelope>>(
                valueListenable: controller.mailboxStorage[mailBox]!.dataStream,
                builder: (context, Box<StorageMessageEnvelope> box, child) {
                  if (box.isEmpty) {
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

                  // Sort and group messages by date
                  List<StorageMessageEnvelope> rows =
                  box.values.sorted((a, b) => b.date!.compareTo(a.date!));
                  Map<DateTime, List<StorageMessageEnvelope>> group = groupBy(
                    rows,
                        (p) => filterDate(p.date ?? DateTime.now()),
                  );

                  return ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: group.length,
                    itemBuilder: (context, index) {
                      var item = group.entries.elementAt(index);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Date header with improved styling
                          Container(
                            margin: const EdgeInsets.only(
                                left: 16, right: 16, top: 16, bottom: 8
                            ),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _formatDateHeader(
                                item.value.isNotEmpty
                                    ? item.value.first.date!
                                    : DateTime.now(),
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryColor,
                              ),
                            ),
                          ),

                          // List of emails for this date group
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            itemBuilder: (context, i) {
                              var mail = item.value.elementAt(i).toMimeMessage();
                              return _buildMailTile(mail, context);
                            },
                            separatorBuilder: (context, i) => Divider(
                              color: Colors.grey.shade200,
                              height: 1,
                              indent: 64,
                              endIndent: 16,
                            ),
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
        // Floating action button for composing new email
        floatingActionButton: FloatingActionButton(
          onPressed: () {
            Get.toNamed('/compose');
          },
          backgroundColor: AppTheme.primaryColor,
          child: const Icon(Icons.edit_outlined),
          elevation: 2,
        ),
        // Selection bottom navigation bar with animation
        bottomNavigationBar: Obx(
              () => AnimatedSlide(
            offset: selectionController.isSelecting
                ? const Offset(0, 0)
                : const Offset(0, 1),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: AnimatedOpacity(
              opacity: selectionController.isSelecting ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: SelectionBottomNav(
                box: mailBox,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Enhanced mail tile with better visual hierarchy and animations
  Widget _buildMailTile(MimeMessage mail, BuildContext context) {
    return Hero(
      tag: 'mail_${mail.guid}',
      child: Material(
        color: Colors.transparent,
        child: MailTile(
          onTap: () {
            Get.to(
                  () => ShowMessage(
                message: mail,
                mailbox: mailBox,
              ),
              // Removed transition parameter for compatibility
              duration: const Duration(milliseconds: 300),
            );
          },
          message: mail,
          mailBox: mailBox,
        ),
      ),
    );
  }

  // Format date header with more human-readable format
  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else if (now.difference(date).inDays < 7) {
      // Within the last week, show day name
      return timeago.format(date, locale: 'en_short');
    } else if (date.year == now.year) {
      // Same year, show month and day
      return '${_getMonthName(date.month)} ${date.day}';
    } else {
      // Different year, show month, day and year
      return '${_getMonthName(date.month)} ${date.day}, ${date.year}';
    }
  }

  // Helper to get month name
  String _getMonthName(int month) {
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return months[month - 1];
  }

  // Show mailbox options bottom sheet
  void _showMailboxOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surfaceColor,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar for better UX
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            _buildOptionTile(
              icon: Icons.refresh_rounded,
              title: 'Refresh',
              onTap: () {
                Navigator.pop(context);
                controller.loadEmailsForBox(mailBox);
              },
            ),

            _buildOptionTile(
              icon: Icons.mark_email_read_outlined,
              title: 'Mark all as read',
              onTap: () {
                Navigator.pop(context);
                controller.markAllAsRead(mailBox);
              },
            ),

            _buildOptionTile(
              icon: Icons.sort_rounded,
              title: 'Sort by',
              onTap: () {
                Navigator.pop(context);
                _showSortOptions(context);
              },
            ),

            _buildOptionTile(
              icon: Icons.filter_list_rounded,
              title: 'Filter',
              onTap: () {
                Navigator.pop(context);
                // Show filter options
              },
            ),

            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // Build option tile for bottom sheet
  Widget _buildOptionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.primaryColor.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(
          icon,
          color: AppTheme.primaryColor,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: AppTheme.textPrimaryColor,
        ),
      ),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }

  // Show sort options dialog
  void _showSortOptions(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Sort by',
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildSortOption(
              title: 'Date (newest first)',
              isSelected: true,
              onTap: () {
                Navigator.pop(context);
                // Apply sort
              },
            ),
            _buildSortOption(
              title: 'Date (oldest first)',
              isSelected: false,
              onTap: () {
                Navigator.pop(context);
                // Apply sort
              },
            ),
            _buildSortOption(
              title: 'Sender',
              isSelected: false,
              onTap: () {
                Navigator.pop(context);
                // Apply sort
              },
            ),
            _buildSortOption(
              title: 'Subject',
              isSelected: false,
              onTap: () {
                Navigator.pop(context);
                // Apply sort
              },
            ),
          ],
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        backgroundColor: AppTheme.surfaceColor,
      ),
    );
  }

  // Build sort option for dialog
  Widget _buildSortOption({
    required String title,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return ListTile(
      title: Text(
        title,
        style: TextStyle(
          color: AppTheme.textPrimaryColor,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      leading: isSelected
          ? Icon(
        Icons.check_circle,
        color: AppTheme.primaryColor,
      )
          : Icon(
        Icons.circle_outlined,
        color: AppTheme.textSecondaryColor,
      ),
      onTap: onTap,
    );
  }
}
