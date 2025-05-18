import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/compose/compose.dart';

import '../../../../app/controllers/mailbox_controller.dart';

class ViewMessageBottomNav extends StatelessWidget {
  ViewMessageBottomNav({
    super.key,
    required this.mailbox,
    required this.message,
  });

  final MimeMessage message;
  final Mailbox mailbox;
  final mailController = Get.find<MailBoxController>();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: const Color.fromRGBO(255, 255, 255, 1).withOpacity(0.8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButtons(
            isImage:false,
            icon: CupertinoIcons.trash,
            onTap: () {
              showCupertinoModalPopup(
                context: context,
                builder: (context) => CupertinoActionSheet(
                  title: Text('are_you_u_wtd'.tr),
                  actions: [
                    CupertinoActionSheetAction(
                      onPressed: () {
                        mailController.deleteMails([message], mailbox);
                        Get.back();
                        Get.back();
                      },
                      isDestructiveAction: true,
                      child: Text('delete'.tr),
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
          ),
          IconButtons(
            icon: CupertinoIcons.reply,
            isImage: false,
            onTap: () {
              Get.to(() => const ComposeScreen(), arguments: {
                'message': message,
                'type': 'reply',
              });
            },
          ),
          IconButtons(
            icon: CupertinoIcons.reply_all,
            isImage: false,
            onTap: () {
              Get.to(() => const ComposeScreen(), arguments: {
                'message': message,
                'type': 'reply_all',
              });
            },
          ),
          IconButtons(
            icon: CupertinoIcons.forward,
            isImage: false,
            onTap: () {
              Get.to(() => const ComposeScreen(), arguments: {
                'message': message,
                'type': 'forward',
              });
            },
          )
        ],
      ),
    );
  }
}

Widget bottomButton(VoidCallback onTap, String text, IconData icon) {
  return InkWell(
    onTap: onTap,
    child: Container(
      width: 70,
      height: 70,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        // border: Border.all(),
        color: Colors.blue.withOpacity(0.4),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    ),
  );
}

class IconButtons extends StatelessWidget {
  const IconButtons(
      {super.key, this.icon, this.isImage = true, this.image, this.onTap});
  final IconData? icon;
  final bool isImage;
  final String? image;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        height: 25,
        child: isImage
            ? Image.asset(
                image!,
                color: Colors.blue,
              )
            : Icon(
                icon,
                color: Colors.blue,
              ),
      ),
    );
  }
}
