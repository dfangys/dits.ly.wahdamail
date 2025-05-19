import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/email_operation_controller.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import '../app/controllers/selection_controller.dart';
import '../app/controllers/settings_controller.dart';
import '../utills/funtions.dart';
import '../utills/theme/app_theme.dart';

class MailTile extends StatelessWidget {
  MailTile({
    super.key,
    required this.onTap,
    required this.message,
    required this.mailBox,
    this.onLongPress, // Added onLongPress parameter
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress; // Added onLongPress callback
  final MimeMessage message;
  final Mailbox mailBox;

  final settingController = Get.find<SettingController>();
  final selectionController = Get.find<SelectionController>();
  final operationController = Get.find<EmailOperationController>(); // Updated to use EmailOperationController

  String get name {
    if ((["sent", "drafts"].contains(mailBox.name.toLowerCase())) &&
        message.to != null &&
        message.to!.isNotEmpty) {
      return message.to!.first.personalName ?? message.to!.first.email;
    }
    if (message.from != null && message.from!.isNotEmpty) {
      return message.from!.first.personalName ?? message.from!.first.email;
    }
    return "Unknown";
  }

  // Optimized method to check for attachments
  bool get hasAttachments {
    // Use the built-in method from enough_mail
    return message.hasAttachments();
  }

  @override
  Widget build(BuildContext context) {
    final bool isUnread = !message.isSeen;
    final bool hasFlagged = message.isFlagged;

    return SlidableAutoCloseBehavior(
      child: Slidable(
        startActionPane: ActionPane(
            motion: const StretchMotion(),
            children: [
              Obx(
                    () => SlidableAction(
                  onPressed: (context) {
                    operationController.ltrTap(message, mailBox); // Updated to use operationController
                  },
                  backgroundColor:
                  settingController.swipeGesturesLTRModel.backgroundColor,
                  icon: settingController.swipeGesturesLTRModel.icon,
                  label: settingController.swipeGesturesLTRModel.text,
                  borderRadius: BorderRadius.circular(8),
                ),
              )
            ]
        ),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          children: [
            Obx(
                  () => SlidableAction(
                onPressed: (context) {
                  operationController.rtlTap(message, mailBox); // Updated to use operationController
                },
                backgroundColor:
                settingController.swipeGesturesRTLModel.backgroundColor,
                icon: settingController.swipeGesturesRTLModel.icon,
                label: settingController.swipeGesturesRTLModel.text,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ],
        ),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                try {
                  if (selectionController.isSelecting) {
                    selectionController.toggle(message);
                  } else if (mailBox.name.toLowerCase() == 'drafts') {
                    EasyLoading.showInfo('Loading...');
                    MimeMessage? msg = await operationController
                        .getMailboxStorage(mailBox)
                        .fetchMessageContents(message);
                    msg ??= await operationController.getMailService().client
                        .fetchMessageContents(message);
                    Get.to(
                          () => const ComposeScreen(),
                      arguments: {'type': 'draft', 'message': msg},
                    );
                  } else if (onTap != null) {
                    onTap!.call();
                  }
                } catch (e) {
                  EasyLoading.showError(e.toString());
                } finally {
                  EasyLoading.dismiss();
                }
              },
              onLongPress: () {
                if (onLongPress != null) {
                  onLongPress!.call(); // Use the provided onLongPress callback if available
                } else {
                  selectionController.toggle(message); // Default behavior
                }
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Avatar or selection indicator
                    Obx(
                          () => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        height: 48,
                        width: 48,
                        decoration: BoxDecoration(
                          color: selectionController.selected.contains(message)
                              ? AppTheme.primaryColor
                              : AppTheme.colorPalette[name.hashCode % AppTheme.colorPalette.length],
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: selectionController.selected.contains(message)
                              ? const Icon(Icons.check, color: Colors.white, size: 24)
                              : Text(
                            name.isNotEmpty ? name[0].toUpperCase() : "?",
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Email content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Sender name and time
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: isUnread ? FontWeight.bold : FontWeight.w500,
                                    color: isUnread ? Colors.black : Colors.black87,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Text(
                                mailTileTimeFormat(message.decodeDate()),
                                style: TextStyle(
                                  color: isUnread ? AppTheme.primaryColor : Colors.grey,
                                  fontSize: 12,
                                  fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          // Email address
                          Text(
                            message.from != null && message.from!.isNotEmpty
                                ? message.from![0].email
                                : "",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.black54,
                              fontSize: 13,
                              fontWeight: isUnread ? FontWeight.w500 : FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 6),
                          // Subject and indicators
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      message.decodeSubject() ?? 'no_subject'.tr,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: isUnread ? Colors.black87 : Colors.black54,
                                        fontSize: 14,
                                        fontWeight: isUnread ? FontWeight.w600 : FontWeight.w400,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    // Preview text (if available)
                                    Text(
                                      message.decodeTextPlainPart()?.trim() ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Status indicators column
                              Column(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  // Attachment indicator
                                  if (hasAttachments)
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: isUnread ? AppTheme.primaryColor.withOpacity(0.1) : Colors.grey.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Icon(
                                        Icons.attachment,
                                        color: isUnread ? AppTheme.primaryColor : Colors.grey,
                                        size: 16,
                                      ),
                                    ),
                                  const SizedBox(height: 8),
                                  // Mail status indicator
                                  _buildStatusIndicator(isUnread, hasFlagged),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(bool isUnread, bool hasFlagged) {
    if (mailBox.name.toLowerCase() == 'drafts') {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.edit_document,
          color: Colors.orange,
          size: 16,
        ),
      );
    } else if (mailBox.name.toLowerCase() == 'sent') {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.green.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          Icons.check_circle_outline,
          color: isUnread ? Colors.green : Colors.grey,
          size: 16,
        ),
      );
    } else if (mailBox.name.toLowerCase() == 'trash') {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.red.withOpacity(0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: const Icon(
          Icons.delete_outline,
          color: Colors.red,
          size: 16,
        ),
      );
    } else if (mailBox.isMarked || mailBox.name.toLowerCase() == 'inbox') {
      return Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: hasFlagged ? AppTheme.starColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(
          hasFlagged ? Icons.star : (isUnread ? Icons.circle : Icons.check_circle_outline),
          color: hasFlagged
              ? AppTheme.starColor
              : (isUnread ? AppTheme.primaryColor : Colors.grey),
          size: 16,
        ),
      );
    }
    return const SizedBox.shrink();
  }
}
