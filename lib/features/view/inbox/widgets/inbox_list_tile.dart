import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:get/get.dart';
import 'package:wahda_bank/features/view/controllers/inbox_controller.dart';

class WinboxListTile extends StatelessWidget {
  const WinboxListTile({
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
    return ListView.separated(
        padding: const EdgeInsets.only(top: 0.1),
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemBuilder: (_, index) {
          final user = controller.users[index];
          return Slidable(
            startActionPane:
                ActionPane(motion: const StretchMotion(), children: [
              SlidableAction(
                onPressed: (context) => {},
                backgroundColor: Colors.blue.shade200,
                icon: Icons.mark_unread_chat_alt,
                label: 'Mark as read',
              )
            ]),
            endActionPane: ActionPane(
              motion: const BehindMotion(),
              children: [
                SlidableAction(
                  onPressed: (context) => {},
                  backgroundColor: Colors.red,
                  icon: Icons.delete,
                  label: 'Delete',
                ),
              ],
            ),
            child: Container(
              padding: const EdgeInsets.all(10),
              width: double.infinity,
              color: Theme.of(context).scaffoldBackgroundColor,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                      const Spacer(),
                      Text(
                        '2:31 PM',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(
                        width: 5,
                      ),
                      selected
                          ? const Image(
                              image: AssetImage('assets/png/attatch.png'),
                              height: 10,
                            )
                          : Container()
                    ],
                  ),
                  Text(
                    user.email,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 4.0),
                  Text(
                    user.subject,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall!
                        .apply(color: Colors.grey),
                  ),
                ],
              ),
            ),
          );
        },
        separatorBuilder: (_, __) => Divider(
              height: 2,
              color: Colors.grey.shade300,
            ),
        itemCount: controller.users.length);
  }
}
