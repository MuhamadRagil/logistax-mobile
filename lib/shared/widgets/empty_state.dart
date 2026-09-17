import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? action;

  const EmptyState({
    super.key,
    this.icon = Icons.inbox_rounded,
    required this.title,
    this.description,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Icon(icon, size: 32, color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            Text(title, style: theme.textTheme.titleMedium, textAlign: TextAlign.center),
            if (description != null) ...[
              const SizedBox(height: 6),
              Text(
                description!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 16), action!],
          ],
        ),
      ),
    );
  }
}
