// lib/features/attachments/presentation/widgets/attachment_chip.dart
import 'package:flutter/material.dart';

class AttachmentChip extends StatelessWidget {
  final Widget? icon;
  final String label;
  final VoidCallback? onTap;
  final String? semanticsLabel;
  const AttachmentChip({
    super.key,
    this.icon,
    required this.label,
    this.onTap,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: onTap != null,
      label: semanticsLabel ?? label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minHeight: 44,
            minWidth: 44,
            maxWidth: 320,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: theme.dividerColor),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[icon!, const SizedBox(width: 6)],
                  Flexible(
                    child: Text(
                      label,
                      style: theme.textTheme.bodySmall,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
