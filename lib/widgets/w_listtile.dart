import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/views/view/controllers/inbox_controller.dart';
import 'package:wahda_bank/utills/popups/full_screen_loader.dart';
import 'package:wahda_bank/widgets/listile/showDialogueBox.dart';

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
    final controller = Get.put(InboxController());

    return SlidableAutoCloseBehavior(
      closeWhenOpened: true,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 100),
        shrinkWrap: true,
        physics: const BouncingScrollPhysics(),
        itemCount: controller.users.length,
        itemBuilder: (BuildContext context, int index) {
          final user = controller.users[index];
          return Slidable(
            startActionPane:
                ActionPane(motion: const StretchMotion(), children: [
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
                    }),
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
                          user.firstLetter,
                          style: const TextStyle(color: Colors.white),
                          textAlign: TextAlign.center,
                        ),
                      )
                    : const Icon(Icons.check, color: Colors.white),
              ),
              title: Text(
                user.name,
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
                    user.email,
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
                    user.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.grey, fontSize: 12),
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  const Text(
                    'Wed 7:32 AM',
                    style: TextStyle(
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
        },
        separatorBuilder: (_, __) => Divider(
          height: 2,
          color: Colors.grey.shade300,
        ),
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
              const Text('Deleted'),
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
                  child: const Center(
                    child: Text('Undo'),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
      backgroundColor: Colors.red,
      icon: Icons.delete,
      label: 'Delete',
    );
  }
}
