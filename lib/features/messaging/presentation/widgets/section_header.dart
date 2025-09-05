// lib/features/messaging/presentation/widgets/section_header.dart
import 'package:flutter/material.dart';
import 'package:wahda_bank/design_system/theme/tokens.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  const SectionHeader({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      header: true,
      label: 'Section: $title',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space5,
          vertical: Tokens.space4,
        ),
        child: Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          softWrap: false,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.textTheme.bodySmall?.color,
          ),
        ),
      ),
    );
  }
}
