// lib/design_system/components/empty_state.dart
import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  const EmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 48,
            color: theme.colorScheme.primary.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleLarge),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(
              message!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
