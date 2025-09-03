// lib/design_system/components/error_state.dart
import 'package:flutter/material.dart';

class ErrorState extends StatelessWidget {
  final String title;
  final String? message;
  final IconData icon;
  const ErrorState({super.key, required this.title, this.message, this.icon = Icons.error_outline});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: theme.colorScheme.error.withOpacity(0.8)),
          const SizedBox(height: 12),
          Text(title, style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.error)),
          if (message != null) ...[
            const SizedBox(height: 8),
            Text(message!, style: theme.textTheme.bodyMedium),
          ]
        ],
      ),
    );
  }
}

