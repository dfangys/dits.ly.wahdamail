// lib/features/attachments/presentation/widgets/preview_stub.dart
import 'package:flutter/material.dart';

class AttachmentPreviewStub extends StatelessWidget {
  final IconData icon;
  final String label;
  const AttachmentPreviewStub({super.key, this.icon = Icons.attach_file, required this.label});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor),
      ),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(child: Text(label, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}

