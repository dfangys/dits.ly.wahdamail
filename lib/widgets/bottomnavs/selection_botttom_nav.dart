import 'package:collection/collection.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/app/controllers/mailbox_controller.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';
import 'package:wahda_bank/utills/extensions.dart';

import '../../app/controllers/selection_controller.dart';

class SelectionBottomNav extends StatelessWidget {
  SelectionBottomNav({
    super.key,
    required this.box,
  });

  final Mailbox box;

  final selectionController = Get.find<SelectionController>();
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
                      onPressed: () async {
                        Get.back();
                        await mailController.deleteMails(
                          selectionController.selected,
                          box,
                        );
                        selectionController.clear();
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
            icon: CupertinoIcons.mail_solid,
            isImage: false,
            onTap: () async {
              mailController.markAsReadUnread(
                selectionController.selected,
                box,
                false,
              );
              selectionController.clear();
            },
          ),
          IconButtons(
            icon: CupertinoIcons.envelope_open,
            isImage: false,
            onTap: () async {
              await mailController.markAsReadUnread(
                selectionController.selected,
                box,
              );
              selectionController.clear();
            },
          ),
          IconButtons(
            icon: CupertinoIcons.move,
            isImage: false,
            onTap: () {
              showCupertinoModalPopup(
                context: context,
                builder: (context) => CupertinoActionSheet(
                  title: Text('move_to'.tr),
                  actions: [
                    for (var item in mailController.mailboxes
                        .whereNot((e) => e == box)
                        .toList())
                      CupertinoActionSheetAction(
                        onPressed: () async {
                          Get.back();
                          await mailController.moveMails(
                            selectionController.selected,
                            box,
                            item,
                          );
                          selectionController.clear();
                        },
                        child: Text(item.name.ucFirst()),
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
