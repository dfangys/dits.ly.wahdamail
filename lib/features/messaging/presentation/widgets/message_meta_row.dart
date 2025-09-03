// lib/features/messaging/presentation/widgets/message_meta_row.dart
import 'package:flutter/material.dart';

class MessageMetaRow extends StatelessWidget {
  final Widget leading;
  final List<Widget> children;
  const MessageMetaRow({super.key, required this.leading, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leading,
        const SizedBox(height: 0, width: 8),
        Expanded(
          child: DefaultTextStyle.merge(
            style: theme.textTheme.bodySmall!,
            child: Wrap(spacing: 8, runSpacing: 4, children: children),
          ),
        ),
      ],
    );
  }
}

