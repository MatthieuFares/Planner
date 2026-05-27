import 'package:flutter/material.dart';

class WarningsPanel extends StatelessWidget {
  final List<dynamic> warnings;

  const WarningsPanel({
    super.key,
    required this.warnings,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: warnings.isEmpty
          ? null
          : Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Warnings',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (warnings.isEmpty)
              const Text('Aucun warning détecté.')
            else
              Column(
                children: warnings.map((warning) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.warning_amber_rounded),
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