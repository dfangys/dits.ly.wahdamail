import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/features/view/inbox/widgets/app_bar_menu_buton.dart';
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
          onPressed: () {},
          icon: const Icon(Icons.delete),
          padding: EdgeInsets.zero,
        ),
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
        const SizedBox(
          width: 10,
        ),
        const InboxAppBarMenuButton()
      ],
    );
  }
}
