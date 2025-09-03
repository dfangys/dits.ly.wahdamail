// lib/features/messaging/presentation/widgets/mailbox_list_item.dart
import 'package:flutter/material.dart';

class MailboxListItem extends StatelessWidget {
  final Widget leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const MailboxListItem({super.key, required this.leading, required this.title, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: ListTile(
        leading: leading,
        title: DefaultTextStyle.merge(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          child: title,
        ),
        subtitle:
            subtitle == null
                ? null
                : DefaultTextStyle.merge(
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    softWrap: true,
                    child: subtitle!,
                  ),
        trailing: trailing,
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        minVerticalPadding: 8,
      ),
    );
  }
}

