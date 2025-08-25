import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/inbox_app_bar.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/inbox_bottom_navbar.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/mail_attachments.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/mail_meta_tile.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class ShowMessage extends StatelessWidget {
  ShowMessage({super.key, required this.message, required this.mailbox});
  final MimeMessage message;
  final Mailbox mailbox;

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
    return DateFormat("EEE, MMM d, yyyy • h:mm a").format(
      message.decodeDate() ?? DateTime.now(),
    );
  }

  // Get initials for avatar
  String get initials {
    if (name.isEmpty) return "?";

    final nameParts = name.split(" ");
    if (nameParts.length > 1) {
      return "${nameParts.first[0]}${nameParts.last[0]}".toUpperCase();
    }
    return name[0].toUpperCase();
  }

  // Get color for avatar based on name
  Color get avatarColor {
    if (name.isEmpty) return AppTheme.primaryColor;

    // Use a consistent color based on the name
    final colorIndex = name.codeUnits.fold<int>(
        0, (prev, element) => prev + element) % AppTheme.colorPalette.length;
    return AppTheme.colorPalette[colorIndex];
  }

  final ValueNotifier<bool> showMeta = ValueNotifier<bool>(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundColor,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(60),
        child: InbocAppBar(
          message: message,
          mailbox: mailbox,
        ),
      ),
      bottomNavigationBar: ViewMessageBottomNav(
        mailbox: mailbox,
        message: message,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Email header card
              Card(
                margin: const EdgeInsets.all(12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Subject
                      Text(
                        message.decodeSubject() ?? 'No Subject',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Sender info with avatar
                      InkWell(
                        borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                        onTap: () {
                          showMeta.value = !showMeta.value;
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              // Avatar
                              CircleAvatar(
                                backgroundColor: avatarColor,
                                radius: 24.0,
                                child: Text(
                                  initials,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(width: 12),

                              // Sender details
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            name,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Text(
                                          date,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      email,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: AppTheme.textSecondaryColor,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),

                              // Expand/collapse icon
                              ValueListenableBuilder(
                                valueListenable: showMeta,
                                builder: (context, isExpanded, _) => Icon(
                                  isExpanded
                                      ? Icons.keyboard_arrow_up
                                      : Icons.keyboard_arrow_down,
                                  color: AppTheme.textSecondaryColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Email metadata (recipients, cc, etc.)
                      MailMetaTile(message: message, isShow: showMeta),
                    ],
                  ),
                ),
              ),

              // Email content and attachments
              Card(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: MailAttachments(message: message),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
