// lib/features/attachments/presentation/widgets/attachment_chip.dart
import 'package:flutter/material.dart';

class AttachmentChip extends StatelessWidget {
  final Widget? icon;
  final String label;
  final VoidCallback? onTap;
  const AttachmentChip({super.key, this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[icon!, const SizedBox(width: 6)],
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

