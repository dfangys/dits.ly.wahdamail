import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:wahda_bank/models/hive_mime_storage.dart';
import '../../app/controllers/mailbox_controller.dart';

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
      body: Obx(
        () {
          if (controller.isBusy()) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }
          return ValueListenableBuilder<Box<StorageMessageEnvelope>>(
            valueListenable: controller.mailboxStorage[box]!.dataStream,
            builder: (context, value, child) {
              // show empyt message if no emails
              if (value.isEmpty) {
                return const Center(
                  child: Text('No Emails'),
                );
              }
              return ListView.separated(
                itemBuilder: (context, index) {
                  MimeMessage item = value.getAt(index)!.toMimeMessage();
                  return ListTile(
                    leading: CircleAvatar(
                      child: Text(
                        index.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ),
                    title: Text(item.from![0].email),
                    subtitle: Text(item.decodeSubject() ?? ''),
                    onTap: () {},
                  );
                },
                separatorBuilder: (context, index) => const Divider(),
                itemCount: value.length,
              );
            },
          );
        },
      ),
    );
  }
}
