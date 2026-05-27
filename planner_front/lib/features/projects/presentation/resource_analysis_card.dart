import 'package:flutter/material.dart';

class ResourceAnalysisCard extends StatelessWidget {
  final Map<String, dynamic> analysis;

  const ResourceAnalysisCard({
    super.key,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    final entries = analysis.entries.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Analyse ressources',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (entries.isEmpty)
              const Text('Aucune donnée ressource.')
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: entries.map((entry) {
                  return _ResourceAnalysisItem(
                    label: _formatKey(entry.key),
                    value: _formatValue(entry.value),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  String _formatKey(String key) {
    final formatted = key
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
        )
        .trim();

    if (formatted.isEmpty) return key;

    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  String _formatValue(dynamic value) {
    if (value == null) return '-';

    if (value is String) {
      final parsedDate = DateTime.tryParse(value);

      if (parsedDate != null && value.contains('T')) {
        final day = parsedDate.day.toString().padLeft(2, '0');
        final month = parsedDate.month.toString().padLeft(2, '0');
        final year = parsedDate.year.toString();

        return '$day/$month/$year';
      }

      return value;
    }

    if (value is List) {
      return '${value.length} élément(s)';
    }

    if (value is Map) {
      return '${value.length} champ(s)';
    }

    return value.toString();
  }
}

class _ResourceAnalysisItem extends StatelessWidget {
  final String label;
  final String value;

  const _ResourceAnalysisItem({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 190,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}