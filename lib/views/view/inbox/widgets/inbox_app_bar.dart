import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/view/inbox/widgets/app_bar_menu_buton.dart';
import 'package:wahda_bank/utills/theme/app_theme.dart';

class InbocAppBar extends StatelessWidget {
  const InbocAppBar({
    super.key,
    required this.indicator,
  });

  final bool indicator;

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
          icon: indicator
              ? const Icon(
                  Icons.star,
                  color: AppTheme.starColor,
                )
              : const Icon(Icons.star_border_outlined),
          onPressed: () {},
        ),
        // const InboxAppBarMenuButton()
        IconButton(
          onPressed: () {
            showCupertinoModalPopup(
              context: context,
              builder: (context) => CupertinoActionSheet(
                title: const Text('Move Message'),
                actions: [
                  CupertinoActionSheetAction(
                    onPressed: () {},
                    child: const Text('Move to archive'),
                  ),
                  CupertinoActionSheetAction(
                    onPressed: () {},
                    child: const Text('Move to sent'),
                  ),
                  CupertinoActionSheetAction(
                    onPressed: () {},
                    child: const Text('Move to draft'),
                  ),
                ],
                cancelButton: CupertinoActionSheetAction(
                  onPressed: () {
                    Get.back();
                  },
                  child: const Text('Cancel'),
                ),
              ),
            );
          },
          icon: Icon(Icons.more_vert),
        )
      ],
    );
  }
}
