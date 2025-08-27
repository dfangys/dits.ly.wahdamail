import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/inbox_app_bar.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/inbox_bottom_navbar.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/mail_attachments.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/mail_meta_tile.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class ShowMessage extends StatelessWidget {
  ShowMessage({super.key, required this.message, required this.mailbox});
  final MimeMessage message;
  final Mailbox mailbox;

  // Enhanced subject with proper fallback handling (enough_mail best practice)
  String get subject {
    final decodedSubject = message.decodeSubject();
    if (kDebugMode) {
      print('DEBUG: Subject - decodedSubject: $decodedSubject');
      print('DEBUG: Subject - envelope.subject: ${message.envelope?.subject}');
      print('DEBUG: Subject - headers: ${message.headers}');
    }
    
    if (decodedSubject == null || decodedSubject.trim().isEmpty) {
      // Try envelope subject as fallback
      if (message.envelope?.subject != null && message.envelope!.subject!.trim().isNotEmpty) {
        return message.envelope!.subject!.trim();
      }
      return 'No Subject';
    }
    return decodedSubject.trim();
  }

  // Enhanced sender name with proper fallback chain (enough_mail best practice)
  String get name {
    // Try from field first
    if (message.from != null && message.from!.isNotEmpty) {
      final from = message.from!.first;
      if (from.personalName != null && from.personalName!.trim().isNotEmpty) {
        return from.personalName!.trim();
      }
      return from.email;
    }
    
    // Try sender field as fallback
    if (message.sender != null) {
      if (message.sender!.personalName != null && message.sender!.personalName!.trim().isNotEmpty) {
        return message.sender!.personalName!.trim();
      }
      return message.sender!.email;
    }
    
    // Try fromEmail as last resort
    if (message.fromEmail != null && message.fromEmail!.trim().isNotEmpty) {
      return message.fromEmail!.trim();
    }
    
    return "Unknown Sender";
  }

  // Enhanced email address with proper fallback chain (enough_mail best practice)
  String get email {
    // Try from field first
    if (message.from != null && message.from!.isNotEmpty) {
      return message.from!.first.email;
    }
    
    // Try sender field as fallback
    if (message.sender != null) {
      return message.sender!.email;
    }
    
    // Try fromEmail as last resort
    if (message.fromEmail != null && message.fromEmail!.trim().isNotEmpty) {
      return message.fromEmail!.trim();
    }
    
    return "unknown@example.com";
  }

  // Enhanced date formatting with timezone awareness (enough_mail best practice)
  String get date {
    final messageDate = message.decodeDate();
    if (messageDate == null) {
      return "Date unknown";
    }
    
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDay = DateTime(messageDate.year, messageDate.month, messageDate.day);
    
    // Professional date formatting based on recency
    if (messageDay == today) {
      // Today: show time only
      return DateFormat("h:mm a").format(messageDate);
    } else if (messageDay == today.subtract(const Duration(days: 1))) {
      // Yesterday
      return "Yesterday ${DateFormat("h:mm a").format(messageDate)}";
    } else if (now.difference(messageDate).inDays < 7) {
      // This week: show day name and time
      return DateFormat("EEE h:mm a").format(messageDate);
    } else if (messageDate.year == now.year) {
      // This year: show month, day, and time
      return DateFormat("MMM d, h:mm a").format(messageDate);
    } else {
      // Different year: show full date
      return DateFormat("MMM d, yyyy h:mm a").format(messageDate);
    }
  }

  // Enhanced detailed date for header display
  String get detailedDate {
    final messageDate = message.decodeDate();
    if (kDebugMode) {
      print('DEBUG: Date - decodeDate: $messageDate');
      print('DEBUG: Date - envelope.date: ${message.envelope?.date}');
      print('DEBUG: Date - headers date: ${message.getHeaderValue("date")}');
    }
    
    if (messageDate == null) {
      // Try envelope date as fallback
      if (message.envelope?.date != null) {
        return DateFormat("EEE, MMM d, yyyy 'at' h:mm a").format(message.envelope!.date!);
      }
      
      // Try header date as fallback
      final headerDate = message.getHeaderValue("date");
      if (headerDate != null) {
        try {
          final parsedDate = DateTime.parse(headerDate);
          return DateFormat("EEE, MMM d, yyyy 'at' h:mm a").format(parsedDate);
        } catch (e) {
          if (kDebugMode) {
            print('DEBUG: Failed to parse header date: $headerDate');
          }
        }
      }
      
      return "Date unknown";
    }
    
    return DateFormat("EEE, MMM d, yyyy 'at' h:mm a").format(messageDate);
  }

  // Enhanced initials generation with better fallback handling
  String get initials {
    if (name.isEmpty || name == "Unknown Sender") return "?";

    final cleanName = name.trim();
    final nameParts = cleanName.split(RegExp(r'\s+'));
    
    if (nameParts.length > 1) {
      // First and last name initials
      return "${nameParts.first[0]}${nameParts.last[0]}".toUpperCase();
    } else if (cleanName.isNotEmpty) {
      // Single name or email - take first character
      return cleanName[0].toUpperCase();
    }
    
    return "?";
  }

  // Message status indicators (enough_mail best practice)
  bool get hasAttachments {
    return message.hasAttachments();
  }

  bool get isAnswered {
    return message.isAnswered;
  }

  bool get isForwarded {
    return message.isForwarded;
  }

  bool get isFlagged {
    return message.isFlagged;
  }

  bool get isSeen {
    return message.isSeen;
  }

  // Thread information
  int get threadLength {
    final threadSequence = message.threadSequence;
    return threadSequence != null ? threadSequence.toList().length : 0;
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
                      // Enhanced subject with proper fallback handling
                      Text(
                        subject,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: isSeen ? FontWeight.w600 : FontWeight.bold,
                          color: isSeen ? null : Theme.of(context).colorScheme.onSurface,
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
                                          detailedDate,
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: AppTheme.textSecondaryColor,
                                          ),
                                        ),
                                        
                                        // Message status indicators (enough_mail best practice)
                                        if (hasAttachments || isAnswered || isForwarded || isFlagged || threadLength > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(left: 8),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (isFlagged)
                                                  const Icon(
                                                    Icons.flag,
                                                    size: 14,
                                                    color: Colors.orange,
                                                  ),
                                                if (hasAttachments)
                                                  const Padding(
                                                    padding: EdgeInsets.only(left: 4),
                                                    child: Icon(
                                                      Icons.attach_file,
                                                      size: 14,
                                                      color: AppTheme.textSecondaryColor,
                                                    ),
                                                  ),
                                                if (isAnswered)
                                                  const Padding(
                                                    padding: EdgeInsets.only(left: 4),
                                                    child: Icon(
                                                      Icons.reply,
                                                      size: 14,
                                                      color: Colors.blue,
                                                    ),
                                                  ),
                                                if (isForwarded)
                                                  const Padding(
                                                    padding: EdgeInsets.only(left: 4),
                                                    child: Icon(
                                                      Icons.forward,
                                                      size: 14,
                                                      color: Colors.green,
                                                    ),
                                                  ),
                                                if (threadLength > 0)
                                                  Padding(
                                                    padding: const EdgeInsets.only(left: 4),
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                                      decoration: BoxDecoration(
                                                        color: AppTheme.primaryColor,
                                                        borderRadius: BorderRadius.circular(8),
                                                      ),
                                                      child: Text(
                                                        threadLength.toString(),
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.white,
                                                          fontWeight: FontWeight.bold,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
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
                  child: MailAttachments(message: message, mailbox: mailbox),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
