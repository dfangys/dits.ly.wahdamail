import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/views/compose/compose.dart';
import 'package:wahda_bank/widgets/search/search.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class MailMetaTile extends StatelessWidget {
  const MailMetaTile({super.key, required this.message, required this.isShow});
  final MimeMessage message;
  final ValueNotifier<bool> isShow;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: isShow,
      builder: (context, value, child) => AnimatedCrossFade(
        firstChild: const SizedBox.shrink(),
        secondChild: Padding(
          padding: const EdgeInsets.only(top: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundColor,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius),
            ),
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                buildMailInfo(
                  "From",
                  message.from != null
                      ? message.from!.map((e) => e.email).toList()
                      : [],
                ),
                buildMailInfo(
                  "To",
                  message.to != null
                      ? message.to!.map((e) => e.email).toList()
                      : [],
                ),
                buildMailInfo(
                  "Cc",
                  message.cc != null
                      ? message.cc!.map((e) => e.email).toList()
                      : [],
                ),
                buildMailInfo(
                  "Bcc",
                  message.bcc != null
                      ? message.bcc!.map((e) => e.email).toList()
                      : [],
                ),
                buildMailInfo(
                  "Date",
                  [
                    DateFormat("EEEE, MMMM d, yyyy 'at' h:mm a").format(
                      message.decodeDate() ?? DateTime.now(),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
        crossFadeState:
        value ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: AppTheme.mediumAnimationDuration,
        sizeCurve: Curves.easeInOut,
        firstCurve: Curves.easeOut,
        secondCurve: Curves.easeIn,
      ),
    );
  }
}

Widget buildMailInfo(String title, List<String> data) {
  if (data.isEmpty) return const SizedBox.shrink();

  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            "$title:",
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondaryColor,
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: data.map((email) =>
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: GestureDetector(
                    onTap: () {
                      if (title == "Date") return;
                      _showEmailOptions(email);
                    },
                    child: Text(
                      email,
                      style: TextStyle(
                        fontSize: 14,
                        color: title == "Date"
                            ? AppTheme.textSecondaryColor
                            : AppTheme.primaryColor,
                      ),
                    ),
                  ),
                )
            ).toList(),
          ),
        )
      ],
    ),
  );
}

void _showEmailOptions(String email) {
  showCupertinoModalPopup(
    context: Get.context!,
    builder: (context) => CupertinoActionSheet(
      title: const Text('Email Options'),
      message: Text(email),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () {
            Clipboard.setData(ClipboardData(text: email));
            Navigator.pop(context);

            // Show copy confirmation
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Email address copied to clipboard'),
                backgroundColor: AppTheme.successColor,
                behavior: SnackBarBehavior.floating,
                duration: Duration(seconds: 2),
              ),
            );
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.copy, size: 20, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text("Copy Email Address"),
            ],
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Get.back();
            Get.to(() => const ComposeScreen(), arguments: {
              "to": email,
            });
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.email_outlined, size: 20, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text("New Message"),
            ],
          ),
        ),
        CupertinoActionSheetAction(
          onPressed: () {
            Get.back();
            Get.to(() => SearchView(), arguments: {
              "terms": email,
            });
          },
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.search, size: 20, color: AppTheme.primaryColor),
              SizedBox(width: 8),
              Text("Search"),
            ],
          ),
        ),
      ],
      cancelButton: CupertinoActionSheetAction(
        onPressed: () {
          Navigator.pop(context);
        },
        child: const Text("Cancel"),
      ),
    ),
  );
}
