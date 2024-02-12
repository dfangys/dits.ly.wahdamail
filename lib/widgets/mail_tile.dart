import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';
import 'package:wahda_bank/widgets/w_listtile.dart';

import 'listile/showDialogueBox.dart';

class MailTile extends StatelessWidget {
  const MailTile({
    super.key,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    required this.onDelete,
    this.icon,
    this.iconColor,
    required this.message,
    required this.flag,
  });

  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDelete;
  final IconData? icon;
  final Color? iconColor;
  final MimeMessage message;
  final MailboxFlag flag;

  @override
  Widget build(BuildContext context) {
    return Slidable(
      startActionPane: ActionPane(motion: const StretchMotion(), children: [
        SlidableAction(
          onPressed: (context) => showDialog(
            context: context,
            builder: (BuildContext context) {
              return CupertinoAlertDialog(
                title: const Text('Left to right swipe'),
                content: const ListTileCupertinoDilaogue(),
                actions: [
                  CupertinoDialogAction(
                    child: Text(
                      'Cancel',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    onPressed: () => Get.back(),
                  )
                ],
              );
            },
          ),
          backgroundColor: Colors.blue.shade200,
          icon: Icons.mark_unread_chat_alt,
          label: 'Mark as read\n    /unread',
        )
      ]),
      endActionPane: const ActionPane(
        motion: BehindMotion(),
        children: [
          WDeleteListTile(),
        ],
      ),
      child: ListTile(
        selected: selected,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15.0,
          vertical: 5.0,
        ),
        onLongPress: onLongPress,
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: !selected
              ? Center(
                  child: Text(
                    message.from![0].email[0].toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                )
              : const Icon(Icons.check, color: Colors.white),
        ),
        title: Text(
          message.from![0].personalName ?? message.from![0].email,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
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
              message.decodeSubject() ?? 'No Subject',
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
    );
  }
}
