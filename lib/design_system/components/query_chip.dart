import 'package:flutter/material.dart';
import 'package:wahda_bank/design_system/theme/tokens.dart';

class QueryChip extends StatelessWidget {
  final String label;
  const QueryChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final bg = cs.primaryContainer;
    final fg = cs.onPrimaryContainer;
    return Semantics(
      label: 'Query chip: $label',
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Tokens.space4,
          vertical: Tokens.space2,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(Tokens.radiusSm),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(color: fg),
        ),
      ),
    );
  }
}
