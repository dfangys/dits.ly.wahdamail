import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/app/controllers/selection_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class MailTile extends StatelessWidget {
  final MimeMessage message;
  final Mailbox mailBox;
  final VoidCallback onTap;
  final VoidCallback? onSelect;
  final bool isSelected;

  const MailTile({
    Key? key,
    required this.message,
    required this.mailBox,
    required this.onTap,
    this.onSelect,
    this.isSelected = false,
  }) : super(key: key);

  String get name {
    if (message.from != null && message.from!.isNotEmpty) {
      return message.from!.first.personalName ?? message.from!.first.email;
    } else if (message.fromEmail == null) {
      return "Unknown";
    }
    return message.fromEmail ?? "Unknown";
  }

  String get email {
    if (message.from != null && message.from!.isNotEmpty) {
      return message.from!.first.email;
    } else if (message.fromEmail == null) {
      return "Unknown";
    }
    return message.fromEmail ?? "Unknown";
  }

  String get date {
    final messageDate = message.decodeDate() ?? DateTime.now();
    final now = DateTime.now();

    if (now.difference(messageDate).inDays == 0) {
      // Today - show time only
      return DateFormat("h:mm a").format(messageDate);
    } else if (now.difference(messageDate).inDays < 7) {
      // This week - show day name
      return DateFormat("EEE").format(messageDate);
    } else {
      // Older - show date
      return DateFormat("MMM d").format(messageDate);
    }
  }

  bool get hasAttachments {
    return message.hasAttachments();
  }

  Color get senderColor {
    // Generate a consistent color based on the sender's name
    final colorIndex = name.hashCode % AppTheme.colorPalette.length;
    return AppTheme.colorPalette[colorIndex];
  }

  @override
  Widget build(BuildContext context) {
    final selectionController = Get.find<SelectionController>();
    final isTablet = MediaQuery.of(context).size.width > 600;

    return Obx(() {
      final isCurrentlySelected = isSelected || selectionController.selected.contains(message);

      return Slidable(
        key: ValueKey(message.sequenceId ?? message.guid ?? message.hashCode),
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.6,
          children: [
            CustomSlidableAction(
              onPressed: (_) {
                // Archive action
              },
              backgroundColor: AppTheme.swipeArchiveColor,
              foregroundColor: Colors.white,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                bottomLeft: Radius.circular(12),
              ),
              padding: const EdgeInsets.all(0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.archive_outlined, size: 22),
                  const SizedBox(height: 4),
                  const Text('Archive', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
            CustomSlidableAction(
              onPressed: (_) {
                // Delete action
              },
              backgroundColor: AppTheme.swipeDeleteColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.all(0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline, size: 22),
                  const SizedBox(height: 4),
                  const Text('Delete', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        startActionPane: ActionPane(
          motion: const DrawerMotion(),
          extentRatio: 0.3,
          children: [
            CustomSlidableAction(
              onPressed: (_) {
                // Flag action
              },
              backgroundColor: AppTheme.swipeFlagColor,
              foregroundColor: Colors.white,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(12),
                bottomRight: Radius.circular(12),
              ),
              padding: const EdgeInsets.all(0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.flag_outlined, size: 22),
                  const SizedBox(height: 4),
                  const Text('Flag', style: TextStyle(fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: isCurrentlySelected
                ? AppTheme.primaryColor.withOpacity(0.1)
                : message.isSeen
                ? AppTheme.surfaceColor
                : AppTheme.unreadColor,
            borderRadius: BorderRadius.circular(12),
            boxShadow: message.isSeen
                ? null
                : [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 4,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          margin: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 4,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: selectionController.isSelecting
                    ? () => onSelect != null ? onSelect!() : selectionController.toggle(message)
                    : onTap,
                onLongPress: () {
                  if (!selectionController.isSelecting) {
                    selectionController.isSelecting = true;
                  }
                  if (onSelect != null) {
                    onSelect!();
                  } else {
                    selectionController.toggle(message);
                  }
                  // Add haptic feedback here if available
                },
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: isTablet ? 20 : 16,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Selection indicator or avatar
                      _buildLeadingWidget(isCurrentlySelected),

                      SizedBox(width: isTablet ? 16 : 12),

                      // Email content
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Sender and date
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isTablet ? 16 : 15,
                                      fontWeight: message.isSeen
                                          ? FontWeight.normal
                                          : FontWeight.bold,
                                      color: message.isSeen
                                          ? AppTheme.textPrimaryColor
                                          : AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Date with indicator dot for unread
                                Row(
                                  children: [
                                    if (!message.isSeen)
                                      Container(
                                        width: 8,
                                        height: 8,
                                        margin: const EdgeInsets.only(right: 6),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: AppTheme.primaryColor,
                                        ),
                                      ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: message.isSeen
                                            ? Colors.transparent
                                            : AppTheme.primaryColor.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        date,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: message.isSeen
                                              ? AppTheme.textSecondaryColor
                                              : AppTheme.primaryColor,
                                          fontWeight: message.isSeen
                                              ? FontWeight.normal
                                              : FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            // Subject with indicators for important emails
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                if (message.isFlagged)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(
                                      Icons.star,
                                      size: 16,
                                      color: AppTheme.starColor,
                                    ),
                                  ),
                                Expanded(
                                  child: Text(
                                    message.decodeSubject() ?? '(No subject)',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: isTablet ? 15 : 14,
                                      fontWeight: message.isSeen
                                          ? FontWeight.normal
                                          : FontWeight.w600,
                                      color: AppTheme.textPrimaryColor,
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 6),

                            // Preview and indicators
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                Expanded(
                                  child: Text(
                                    _getPreviewText(),
                                    maxLines: isTablet ? 2 : 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.textSecondaryColor,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Indicators
                                _buildIndicators(),
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
    });
  }

  Widget _buildLeadingWidget(bool isSelected) {
    return AnimatedContainer(
      duration: AppTheme.shortAnimationDuration,
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: isSelected ? AppTheme.primaryColor : senderColor,
        boxShadow: [
          BoxShadow(
            color: (isSelected ? AppTheme.primaryColor : senderColor).withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: isSelected
          ? const Icon(
        Icons.check,
        size: 20,
        color: Colors.white,
      )
          : Center(
        child: Hero(
          tag: 'avatar_${message.sequenceId}',
          child: Text(
            name.isNotEmpty ? name[0].toUpperCase() : '?',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIndicators() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasAttachments)
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.attachmentIconColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.attachment,
              size: 14,
              color: AppTheme.attachmentIconColor,
            ),
          ),
        if (message.isAnswered)
          Container(
            margin: const EdgeInsets.only(left: 4),
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppTheme.textSecondaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.reply,
              size: 14,
              color: AppTheme.textSecondaryColor,
            ),
          ),
      ],
    );
  }

  String _getPreviewText() {
    // Try to get plain text content
    String? preview = message.decodeTextPlainPart();

    // If no plain text, try HTML
    if (preview == null || preview.isEmpty) {
      preview = message.decodeTextHtmlPart();

      // Strip HTML tags if present
      if (preview != null && preview.contains('<')) {
        preview = preview.replaceAll(RegExp(r'<[^>]*>'), ' ');
        preview = preview.replaceAll('&nbsp;', ' ');
      }
    }

    // Clean up whitespace
    if (preview != null) {
      preview = preview.replaceAll(RegExp(r'\s+'), ' ').trim();
    }

    return preview ?? '';
  }
}
