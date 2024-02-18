import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class InbocAppBar extends StatefulWidget {
  const InbocAppBar({
    super.key,
    required this.message,
    required this.mailbox,
  });

  final MimeMessage message;
  final Mailbox mailbox;

  @override
  State<InbocAppBar> createState() => _InbocAppBarState();
}

class _InbocAppBarState extends State<InbocAppBar> {
  bool isStarred = false;
  @override
  void initState() {
    super.initState();
    isStarred = widget.message.isFlagged;
  }

  final controller = Get.find<MailBoxController>();

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.transparent,
      iconTheme: const IconThemeData(color: Colors.black),
      elevation: 0,
      leading: GestureDetector(
        onTap: Get.back,
        child: const Icon(Icons.arrow_back_ios),
      ),
      actions: [
        IconButton(
          padding: EdgeInsets.zero,
          icon: Icon(
            isStarred ? Icons.star : CupertinoIcons.star,
            color: isStarred ? AppTheme.starColor : Colors.grey,
          ),
          onPressed: () async {
            controller.updateFlag([widget.message], controller.mailBoxInbox);
            setState(() {
              isStarred = !isStarred;
            });
          },
        ),
        IconButton(
          onPressed: () {
            showCupertinoModalPopup(
              context: context,
              builder: (context) => CupertinoActionSheet(
                title: Text('move_message'.tr),
                actions: [
                  for (var box in controller.mailboxes
                      .whereNot((e) => e == widget.mailbox)
                      .toList())
                    CupertinoActionSheetAction(
                      onPressed: () {
                        controller.moveMails(
                          [widget.message],
                          widget.mailbox,
                          box,
                        );
                        Get.back();
                      },
                      child: Text("move_to_${box.name.toLowerCase()}".tr),
                    ),
                ],
                cancelButton: CupertinoActionSheetAction(
                  onPressed: () {
                    Get.back();
                  },
                  child: Text('cancel'.tr),
                ),
              ),
            );
          },
          icon: const Icon(Icons.more_vert_outlined),
        )
      ],
    );
  }
}
