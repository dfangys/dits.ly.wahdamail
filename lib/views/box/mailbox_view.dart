import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:lottie/lottie.dart';
import 'package:wahda_bank/models/hive_mime_storage.dart';
import 'package:wahda_bank/views/view/screens/home/home.dart';
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
            return TAnimationLoaderWidget(
              text: 'Whoops! Cart is Empty',
              animation:
                  'https://lottie.host/44b3d113-55e1-4bb7-9412-60f74b5331ef/CDlMVEzeua.json',
              showAction: true,
              actionText: 'Let\'s fill it',
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

class TAnimationLoaderWidget extends StatelessWidget {
  const TAnimationLoaderWidget(
      {super.key,
      required this.text,
      required this.animation,
      this.showAction = false,
      this.actionText,
      this.onActionPressed});
  final String text;
  final String animation;
  final bool showAction;
  final String? actionText;
  final VoidCallback? onActionPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Lottie.network(
            animation,
            width: MediaQuery.of(context).size.width * 0.8,
          ),
          const SizedBox(
            height: 24,
          ),
          Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(
            height: 24,
          ),
          showAction
              ? SizedBox(
                  width: 250,
                  child: OutlinedButton(
                    onPressed: onActionPressed,
                    child: Text(
                      actionText!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium!
                          .apply(color: Colors.grey),
                    ),
                  ))
              : const SizedBox()
        ],
      ),
    );
  }
}
