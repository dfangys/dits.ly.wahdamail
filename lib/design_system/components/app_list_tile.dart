// lib/design_system/components/app_list_tile.dart
import 'package:flutter/material.dart';

class AppListTile extends StatelessWidget {
  final Widget? leading;
  final Widget? title;
  final Widget? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  const AppListTile({
    super.key,
    this.leading,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: leading,
      title: DefaultTextStyle.merge(
        style: theme.textTheme.titleMedium,
        child: title ?? const SizedBox.shrink(),
      ),
      subtitle:
          subtitle == null
              ? null
              : DefaultTextStyle.merge(
                style: theme.textTheme.bodySmall,
                child: subtitle!,
              ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      minVerticalPadding: 8,
    );
  }
}
