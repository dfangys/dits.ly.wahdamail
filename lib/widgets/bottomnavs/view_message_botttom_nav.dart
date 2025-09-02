import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/compose/redesigned_compose_screen.dart';

class InboxBottomNavBar extends StatelessWidget {
  const InboxBottomNavBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      color: const Color.fromRGBO(255, 255, 255, 1).withValues(alpha: 0.8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          IconButtons(
            icon: CupertinoIcons.trash,
            onTap: () {
              showCupertinoModalPopup(
                context: context,
                builder:
                    (context) => CupertinoActionSheet(
                      title: Text('are_you_u_wtd'.tr),
                      actions: [
                        CupertinoActionSheetAction(
                          onPressed: () {},
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
          const IconButtons(
            icon: CupertinoIcons.folder_fill_badge_person_crop,
            isImage: false,
          ),
          const IconButtons(
            icon: CupertinoIcons.arrowshape_turn_up_left,
            isImage: false,
          ),
          IconButtons(
            icon: CupertinoIcons.pencil_outline,
            isImage: false,
            onTap: () => Get.to(() => const RedesignedComposeScreen()),
          ),
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
        color: Colors.blue.withValues(alpha: 0.4),
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
  const IconButtons({
    super.key,
    this.icon,
    this.isImage = true,
    this.image,
    this.onTap,
  });
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
        child:
            isImage
                ? Image.asset(image!, color: Colors.blue)
                : Icon(icon, color: Colors.blue),
      ),
    );
  }
}
