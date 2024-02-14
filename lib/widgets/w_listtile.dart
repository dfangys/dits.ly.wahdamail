import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/view/controllers/inbox_controller.dart';
import 'package:wahda_bank/utills/popups/full_screen_loader.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'mail_tile.dart';

class WListTile extends StatelessWidget {
  const WListTile({
    super.key,
    required this.selected,
    this.onLongPress,
    this.icon,
    this.onTap,
    this.iconColor,
    this.onDelete,
    this.widget,
  });

  final bool selected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final IconData? icon;
  final Color? iconColor;
  final Widget? widget;

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<InboxController>();
    return SlidableAutoCloseBehavior(
      closeWhenOpened: true,
      child: ListView.builder(
        itemCount: controller.mailGroups.length,
        itemBuilder: (BuildContext context, int index) {
          var item = controller.mailGroups.entries.elementAt(index);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  timeago.format(item.key),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemBuilder: (context, i) => MailTile(
                  selected: selected,
                  onTap: onTap,
                  onLongPress: onLongPress,
                  onDelete: onDelete,
                  icon: icon,
                  iconColor: iconColor,
                  message: MimeMessage.parseFromText("text"),
                  flag: MailboxFlag.inbox,
                ),
                itemCount: item.value.length,
                separatorBuilder: (_, __) => Divider(
                  height: 2,
                  color: Colors.grey.shade300,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class WDeleteListTile extends StatelessWidget {
  const WDeleteListTile({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return SlidableAction(
      onPressed: (context) => Get.bottomSheet(
        Container(
          height: 50,
          color: Colors.white,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              const SizedBox(
                width: 1,
              ),
              Text('deleted'.tr),
              InkWell(
                onTap: () {
                  WFullScreenLoader.customToast(message: 'Deleted');
                  Get.back();
                },
                child: Container(
                  height: 30,
                  width: 50,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Center(
                    child: Text('undo'.tr),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
      backgroundColor: Colors.red,
      icon: Icons.delete,
      label: 'delete'.tr,
    );
  }
}
