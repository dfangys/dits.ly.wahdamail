import 'package:flutter/material.dart';

class WListTile extends StatelessWidget {
  const WListTile({
    super.key,
    required this.selected,
    this.onLongPress,
    this.icon,
    this.onTap,
    this.iconColor,
    this.onDelete,
  });

  final bool selected;
  final VoidCallback? onLongPress;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;
  final IconData? icon;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 15.0,
          vertical: 5.0,
        ),
        onLongPress: onLongPress,
        leading: CircleAvatar(
          backgroundColor: Colors.blue,
          child: !selected
              ? const Center(
                  child: Text(
                    'Z',
                    style: TextStyle(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                )
              : const Icon(Icons.check, color: Colors.white),
        ),
        title: const Text(
          'Zaeem Ali',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sed ut perspiciatis unde',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.black,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 4.0),
            Text(
              'Curabitur at interdum manga, a phareta justo. In sed nunc augue ...',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
          ],
        ),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.start, children: [
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
        ]));
  }
}
