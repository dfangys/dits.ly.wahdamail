import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/funtions.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';
import 'package:wahda_bank/views/view/showmessage/show_message.dart';
import 'package:wahda_bank/widgets/bottomnavs/selection_botttom_nav.dart';
import 'package:wahda_bank/widgets/drawer/drawer.dart';
import 'package:wahda_bank/widgets/mail_tile.dart';
import 'package:wahda_bank/widgets/search/search.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/models/hive_mime_storage.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:wahda_bank/widgets/empty_box.dart';

class HomeScreen extends GetView<MailBoxController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final selectionController = Get.find<SelectionController>();

    return Scaffold(
      backgroundColor: AppTheme.cardDesignColor,
      appBar: _buildAppBar(context),
      drawer: const Drawer1(),
      body: Column(
        children: [
          _buildSearchBar(context),
          Expanded(
            child: _buildEmailList(selectionController, context),
          ),
        ],
      ),
      bottomNavigationBar: _buildSelectionBottomNav(selectionController),
      floatingActionButton: _buildComposeButton(context),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      elevation: 0,
      backgroundColor: Theme.of(context).primaryColor,
      title: Row(
        children: [
          SvgPicture.asset(
            WImages.logo,
            // ignore: deprecated_member_use
            color: Colors.white,
            height: 40,
          ),
          const SizedBox(width: 8),

        ],
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh, color: Colors.white),
          onPressed: () => controller.loadEmailsForBox(controller.mailBoxInbox),
          tooltip: 'refresh'.tr,
        ),
        Obx(() => IconButton(
          icon: Icon(
            controller.isBusy() ? Icons.hourglass_top : Icons.filter_list,
            color: Colors.white,
          ),
          onPressed: controller.isBusy() ? null : () {
            // Show filter options
            Get.bottomSheet(
              _buildFilterOptions(context),
              backgroundColor: Colors.white,
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
            );
          },
          tooltip: 'filter'.tr,
        )),
      ],
    );
  }

  Widget _buildFilterOptions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'filter_emails'.tr,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),
          _buildFilterOption(context, Icons.inbox, 'all_emails'.tr, () {
            Get.back();
          }),
          _buildFilterOption(context, Icons.mark_email_unread, 'unread'.tr, () {
            Get.back();
            // Filter unread emails
          }),
          _buildFilterOption(context, Icons.star, 'starred'.tr, () {
            Get.back();
            // Filter starred emails
          }),
          _buildFilterOption(context, Icons.attach_file, 'with_attachments'.tr, () {
            Get.back();
            // Filter emails with attachments
          }),
        ],
      ),
    );
  }

  Widget _buildFilterOption(BuildContext context, IconData icon, String text, VoidCallback onTap) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(text),
      onTap: onTap,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            SearchController().clear();
            Get.to(SearchView());
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  'search_emails'.tr,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 14,
                  ),
                ),
                const Spacer(),
                Icon(
                  Icons.mic,
                  color: Colors.grey.shade600,
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmailList(SelectionController selectionController, BuildContext context) {
    return Obx(() {
      if (controller.isBusy()) {
        return _buildLoadingAnimation();
      }
      return _buildEmailListContent(context);
    });
  }

  Widget _buildLoadingAnimation() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Get.theme.primaryColor,
          ),
          const SizedBox(height: 16),
          Text(
            'loading_emails'.tr,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmailListContent(BuildContext context) {
    return ValueListenableBuilder<Box<StorageMessageEnvelope>>(
      valueListenable: controller.mailboxStorage[controller.mailBoxInbox]!.dataStream,
      builder: (context, box, child) {
        // Extract this logic to a separate method for better performance
        final groupedEmails = _groupEmailsByDate(box);

        if (groupedEmails.isEmpty) {
          return _buildEmptyState();
        }

        return _buildGroupedEmailList(groupedEmails, context);
      },
    );
  }

  Widget _buildEmptyState() {
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
            'no_emails'.tr,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'no_emails_subtitle'.tr,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => controller.loadEmailsForBox(controller.mailBoxInbox),
            style: ElevatedButton.styleFrom(
              backgroundColor: Get.theme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('refresh'.tr),
          ),
        ],
      ),
    );
  }

  Map<DateTime, List<StorageMessageEnvelope>> _groupEmailsByDate(Box<StorageMessageEnvelope> box) {
    // Extract sorting and grouping logic from build method
    final rows = box.values.sorted((a, b) => b.date!.compareTo(a.date!));
    return groupBy(rows, (p) => filterDate(p.date ?? DateTime.now()));
  }

  Widget _buildGroupedEmailList(Map<DateTime, List<StorageMessageEnvelope>> groupedEmails, BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        await controller.loadEmailsForBox(controller.mailBoxInbox);
      },
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 80),
        itemCount: groupedEmails.length,
        itemBuilder: (context, index) {
          var item = groupedEmails.entries.elementAt(index);
          return _buildDateGroup(item, context, index);
        },
      ),
    );
  }

  Widget _buildDateGroup(MapEntry<DateTime, List<StorageMessageEnvelope>> group, BuildContext context, int index) {
    // Use standard animation for a subtle effect
    return FadeTransition(
      opacity: AlwaysStoppedAnimation(1.0), // No animation in standard mode
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                timeago.format(
                  group.value.isNotEmpty ? group.value.first.date! : DateTime.now(),
                ),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).primaryColor,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
          _buildEmailsForDate(group.value),
          const SizedBox(height: 8), // Add spacing between date groups
        ],
      ),
    );
  }

  Widget _buildEmailsForDate(List<StorageMessageEnvelope> emails) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, i) {
        var mail = emails.elementAt(i).toMimeMessage();
        return MailTile(
          onTap: () {
            Get.to(
                  () => ShowMessage(
                message: mail,
                mailbox: controller.mailBoxInbox,
              ),
              duration: const Duration(milliseconds: 300),
            );
          },
          message: mail,
          mailBox: controller.mailBoxInbox,
          isSelected: Get.find<SelectionController>().isSelected(mail),
          onSelect: () => Get.find<SelectionController>().toggle(mail),
        );
      },
      itemCount: emails.length,
    );
  }

  Widget _buildSelectionBottomNav(SelectionController selectionController) {
    return Obx(
          () => AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (Widget child, Animation<double> animation) {
          return SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 1),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          );
        },
        child: selectionController.isSelecting
            ? SelectionBottomNav(
          box: controller.mailBoxInbox,
        )
            : const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildComposeButton(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'compose_fab',
      onPressed: () {
        Get.toNamed('/compose');
      },
      backgroundColor: Theme.of(context).primaryColor,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Icon(
        Icons.edit_outlined,
        color: Colors.white,
      ),
    );
  }
}
