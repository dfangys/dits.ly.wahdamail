// lib/features/messaging/presentation/widgets/message_meta_row.dart
import 'package:flutter/material.dart';
import 'package:wahda_bank/design_system/theme/tokens.dart';

class MessageMetaRow extends StatelessWidget {
  final Widget leading;
  final List<Widget> children;
  const MessageMetaRow({
    super.key,
    required this.leading,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        leading,
        const SizedBox(height: 0, width: Tokens.space3),
        Expanded(
          child: DefaultTextStyle.merge(
            style: theme.textTheme.bodySmall!,
            child: Wrap(
              spacing: Tokens.space3,
              runSpacing: Tokens.space2,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}
