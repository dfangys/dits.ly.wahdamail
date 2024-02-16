import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import '../app/controllers/selection_controller.dart';
import '../app/controllers/settings_controller.dart';

class MailTile extends StatelessWidget {
  MailTile({
    super.key,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    this.icon,
    this.iconColor,
    required this.message,
    required this.flag,
  });

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final IconData? icon;
  final Color? iconColor;
  final MimeMessage message;
  final MailboxFlag flag;

  final settingController = Get.find<SettingController>();
  final selectionController = Get.find<SelectionController>();

  @override
  Widget build(BuildContext context) {
    return SlidableAutoCloseBehavior(
      child: Slidable(
        startActionPane: ActionPane(motion: const StretchMotion(), children: [
          Obx(
            () => SlidableAction(
              onPressed: (context) {
                Get.find<MailBoxController>().ltrTap(message);
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
                  Get.find<MailBoxController>().rtlTap(message);
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
                        message.from![0].email[0].toUpperCase(),
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    )
                  : const Icon(Icons.check, color: Colors.white),
            ),
          ),
          title: Text(
            message.from![0].personalName ?? message.from![0].email,
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
              Text(
                DateFormat("E HH:mm a").format(
                  message.decodeDate() ?? DateTime.now(),
                ),
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(
                height: 5,
              ),
              GestureDetector(
                onTap: onDelete,
                child: InkWell(
                  child: Icon(
                    icon,
                    color: iconColor,
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
