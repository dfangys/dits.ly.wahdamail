import 'package:flutter/material.dart';

class InboxAppBarMenuButton extends StatelessWidget {
  const InboxAppBarMenuButton({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton(
        itemBuilder: (context) => [
              ...[
                PopupMenuItem(
                  onTap: () {
                    // markAs(e, "Inbox");
                  },
                  child: const Text('Move to Inbox'),
                ),
                PopupMenuItem(
                  onTap: () {
                    // markAs(e, "Draft");
                  },
                  child: const Text('Move to Draft'),
                ),
                PopupMenuItem(
                  onTap: () {
                    // markAs(e, "Trash");
                  },
                  child: const Text('Move to Trash'),
                ),
                PopupMenuItem(
                  onTap: () {
                    // markAs(e, "Spam");
                  },
                  child: const Text('Move to Spam'),
                ),
                const PopupMenuItem(
                  child: Text('bn'),
                )
              ],
            ]);
  }
}
