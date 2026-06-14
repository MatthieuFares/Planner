import 'package:flutter/material.dart';

class WarningsPanel extends StatelessWidget {
  final List<dynamic> warnings;

  const WarningsPanel({
    super.key,
    required this.warnings,
  });

  @override
  Widget build(BuildContext context) {
    final hasWarnings = warnings.isNotEmpty;

    return Card(
      color: hasWarnings ? Theme.of(context).colorScheme.errorContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  hasWarnings
                      ? Icons.warning_amber_rounded
                      : Icons.check_circle_outline,
                  color: hasWarnings
                      ? Theme.of(context).colorScheme.error
                      : Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Alertes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (!hasWarnings)
              const Text('Aucune alerte détectée.')
            else
              Column(
                children: warnings.map((warning) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          color: Theme.of(context).colorScheme.error,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(_formatWarning(warning)),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _formatWarning(dynamic warning) {
    if (warning == null) return '-';

    if (warning is String) {
      return warning;
    }

    if (warning is Map<String, dynamic>) {
      if (warning.containsKey('message')) {
        return warning['message'].toString();
      }

      if (warning.containsKey('description')) {
        return warning['description'].toString();
      }

      if (warning.containsKey('title')) {
        return warning['title'].toString();
      }

      return warning.entries
          .map((entry) => '${entry.key}: ${entry.value}')
          .join(' | ');
    }

    return warning.toString();
  }
}