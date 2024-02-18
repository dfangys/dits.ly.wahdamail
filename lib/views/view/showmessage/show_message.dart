import 'package:enough_mail/enough_mail.dart';
import 'package:enough_mail_flutter/enough_mail_flutter.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/services/mail_service.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/inbox_app_bar.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/inbox_bottom_navbar.dart';
import 'package:wahda_bank/utills/constants/sizes.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/mail_attachments.dart';
import 'package:wahda_bank/views/view/showmessage/widgets/mail_meta_tile.dart';

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
    return message.fromEmail ?? "Unknow";
  }

  String get email {
    if (message.from != null && message.from!.isNotEmpty) {
      return message.from!.first.email;
    } else if (message.fromEmail == null) {
      return "Unknown";
    }
    return message.fromEmail ?? "Unknow";
  }

  String get date {
    return DateFormat("EEE hh:mm a").format(
      message.decodeDate() ?? DateTime.now(),
    );
  }

  final ValueNotifier<bool> showMeta = ValueNotifier<bool>(false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 10),
              child: ListTile(
                onTap: () {
                  showMeta.value = !showMeta.value;
                },
                leading: CircleAvatar(
                  backgroundColor:
                      Colors.primaries[0 % Colors.primaries.length],
                  radius: 25.0,
                  child: Text(
                    name[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      email,
                      style: const TextStyle(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                subtitle: Text(
                  (message.decodeDate() ?? DateTime.now()).toString(),
                  maxLines: 1,
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ),
            MailMetaTile(message: message, isShow: showMeta),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                message.decodeSubject() ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: WSizes.defaultSpace),
            MailAttachments(message: message),
            MimeMessageDownloader(
              mimeMessage: message,
              mailClient: MailService.instance.client,
              adjustHeight: true,
              markAsSeen: true,
              onDownloaded: (_msg) {
                Get.find<MailBoxController>().markAsReadUnread(
                  [_msg],
                  mailbox,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
