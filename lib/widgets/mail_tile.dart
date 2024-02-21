import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
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
  });

  final VoidCallback? onTap;
  final MimeMessage message;
  final Mailbox mailBox;

  final settingController = Get.find<SettingController>();
  final selectionController = Get.find<SelectionController>();

  String get name {
    if (mailBox.name.toLowerCase() == 'sent') {
      return message.to!.first.personalName ?? message.to!.first.email;
    }
    if (message.from != null) {
      return message.from!.first.personalName ?? message.from!.first.email;
    }
    return "";
  }

  @override
  Widget build(BuildContext context) {
    return SlidableAutoCloseBehavior(
      child: Slidable(
        startActionPane: ActionPane(motion: const StretchMotion(), children: [
          Obx(
            () => SlidableAction(
              onPressed: (context) {
                Get.find<MailBoxController>().ltrTap(message, mailBox);
              },
              backgroundColor:
                  settingController.swipeGesturesLTRModel.backgroundColor,
              icon: settingController.swipeGesturesLTRModel.icon,
              label: settingController.swipeGesturesLTRModel.text,
            ),
          )
        ]),
        endActionPane: ActionPane(
          motion: const BehindMotion(),
          children: [
            Obx(
              () => SlidableAction(
                onPressed: (context) {
                  Get.find<MailBoxController>().rtlTap(message, mailBox);
                },
                backgroundColor:
                    settingController.swipeGesturesRTLModel.backgroundColor,
                icon: settingController.swipeGesturesRTLModel.icon,
                label: settingController.swipeGesturesRTLModel.text,
              ),
            ),
          ],
        ),
        child: ListTile(
          onTap: () {
            if (selectionController.isSelecting) {
              selectionController.toggle(message);
            } else if (mailBox.name.toLowerCase() == 'drafts') {
              Get.to(
                () => const ComposeScreen(),
                arguments: {'type': 'draft', 'message': message},
              );
            } else if (onTap != null) {
              onTap!.call();
            }
          },
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 15.0,
            vertical: 5.0,
          ),
          onLongPress: () {
            selectionController.toggle(message);
          },
          leading: CircleAvatar(
            child: Obx(
              () => !selectionController.selected.contains(message)
                  ? Center(
                      child: Text(
                        name[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : const Icon(Icons.check, color: Colors.white),
            ),
          ),
          title: Text(
            name,
            style: TextStyle(
              fontSize: 14,
              fontWeight: message.isSeen ? FontWeight.normal : FontWeight.bold,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                message.from![0].email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.black,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4.0),
              Text(
                message.decodeSubject() ?? 'no_subject'.tr,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    mailTileTimeFormat(message.decodeDate()),
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (message.hasAttachments())
                    const Icon(
                      Icons.attach_file,
                      color: Colors.green,
                      size: 12,
                    ),
                ],
              ),
              const SizedBox(
                height: 5,
              ),
              getIcon(),
            ],
          ),
        ),
      ),
    );
  }

  Widget getIcon() {
    if (mailBox.name.toLowerCase() == 'drafts') {
      return const Icon(
        Icons.edit_document,
      );
    } else if (mailBox.name.toLowerCase() == 'sent') {
      return Icon(
        Icons.done,
        color: message.isSeen ? Colors.grey : Colors.blue,
      );
    } else if (mailBox.name.toLowerCase() == 'trash') {
      return const Icon(
        Icons.delete,
        color: Colors.red,
      );
    } else if (mailBox.isMarked || mailBox.name.toLowerCase() == 'inbox') {
      return Icon(
        message.isFlagged ? Icons.star : Icons.star_border,
        color: message.isFlagged ? AppTheme.starColor : Colors.black,
      );
    }
    return const SizedBox.shrink();
  }
}
