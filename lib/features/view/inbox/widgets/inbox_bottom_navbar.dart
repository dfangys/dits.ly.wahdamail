import 'package:flutter/material.dart';
import 'package:wahda_bank/features/view/inbox/inbox.dart';
import 'package:wahda_bank/utills/constants/image_strings.dart';

class InboxBottomNavBar extends StatelessWidget {
  const InboxBottomNavBar({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          bottomButton(
            () {},
            "Reply",
            WImages.reply,
          ),
          Container(width: 2, height: 15, color: Colors.grey),
          bottomButton(
            () {},
            "Reply All",
            WImages.reply,
          ),
          Container(width: 2, height: 15, color: Colors.grey),
          bottomButton(
            () {},
            "Forward",
            WImages.forward,
          ),
        ],
      ),
    );
  }
}
