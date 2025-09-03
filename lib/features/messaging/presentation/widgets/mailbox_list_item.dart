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
    return ListTile(
      leading: leading,
      title: title,
      subtitle: subtitle,
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    );
  }
}

