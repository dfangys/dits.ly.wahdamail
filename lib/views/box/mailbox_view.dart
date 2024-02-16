import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wahda_bank/models/hive_mime_storage.dart';
import '../../app/controllers/mailbox_controller.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../widgets/mail_tile.dart';
import '../view/inbox/show_message.dart';

class MailBoxView extends GetView<MailBoxController> {
  const MailBoxView({super.key, required this.hiveKey, required this.box});

  final String hiveKey;
  final Mailbox box;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(box.name),
      ),
      body: ValueListenableBuilder<Box<StorageMessageEnvelope>>(
        valueListenable: controller.mailboxStorage[box]!.dataStream,
        builder: (context, Box<StorageMessageEnvelope> box, child) {
          if (box.isEmpty) {
            return const Center(
              child: Text("No Messages"),
            );
          }
          List<StorageMessageEnvelope> rows =
              box.values.sorted((a, b) => b.date!.compareTo(a.date!));
          Map<DateTime, List<StorageMessageEnvelope>> group = groupBy(
            rows,
            (p) {
              var dt = p.date ?? DateTime.now();
              return DateTime(dt.year, dt.month);
            },
          );
          return ListView.builder(
            itemCount: group.length,
            itemBuilder: (context, index) {
              var item = group.entries.elementAt(index);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      timeago.format(item.key),
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).primaryColor,
                      ),
                    ),
                  ),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (context, i) {
                      var mail = item.value.elementAt(i).toMimeMessage();
                      return MailTile(
                        onTap: () {
                          Get.to(
                            () => ShowMessage(message: mail),
                          );
                        },
                        message: mail,
                        iconColor: Colors.green,
                        onDelete: () {},
                        onLongPress: () {},
                        flag: MailboxFlag.inbox,
                      );
                    },
                    separatorBuilder: (context, i) => Divider(
                      color: Colors.grey.shade300,
                    ),
                    itemCount: item.value.length,
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}
