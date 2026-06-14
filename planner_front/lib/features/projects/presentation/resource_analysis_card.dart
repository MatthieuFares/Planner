import 'package:flutter/material.dart';

class ResourceAnalysisCard extends StatelessWidget {
  final Map<String, dynamic> analysis;

  const ResourceAnalysisCard({
    super.key,
    required this.analysis,
  });

  @override
  Widget build(BuildContext context) {
    final items = _buildItems(analysis);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.groups_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Analyse ressources',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (items.isEmpty)
              const Text('Aucune donnée ressource.')
            else
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: items.map((item) {
                  return _ResourceAnalysisItem(
                    label: item.label,
                    value: item.value,
                    icon: item.icon,
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  List<_ResourceAnalysisDisplayItem> _buildItems(Map<String, dynamic> data) {
    final orderedKeys = [
      'projectId',
      'totalWorkloadHours',
      'estimatedCost',
      'resources',
      'resourceCount',
      'resourceGroupCount',
      'overloadedResourceCount',
    ];

    final items = <_ResourceAnalysisDisplayItem>[];

    for (final key in orderedKeys) {
      if (!data.containsKey(key)) continue;

      items.add(
        _ResourceAnalysisDisplayItem(
          label: _labelForKey(key),
          value: _formatValue(key, data[key]),
          icon: _iconForKey(key),
        ),
      );
    }

    final remainingEntries = data.entries.where(
      (entry) => !orderedKeys.contains(entry.key),
    );

    for (final entry in remainingEntries) {
      items.add(
        _ResourceAnalysisDisplayItem(
          label: _labelForKey(entry.key),
          value: _formatValue(entry.key, entry.value),
          icon: Icons.info_outline,
        ),
      );
    }

    return items;
  }

  String _labelForKey(String key) {
    const labels = {
      'projectId': 'ID projet',
      'totalWorkloadHours': 'Charge totale',
      'estimatedCost': 'Coût estimé',
      'resources': 'Ressources',
      'resourceCount': 'Nombre de ressources',
      'resourceGroupCount': 'Groupes de ressources',
      'overloadedResourceCount': 'Ressources surchargées',
    };

    return labels[key] ?? _fallbackLabel(key);
  }

  IconData _iconForKey(String key) {
    const icons = {
      'projectId': Icons.badge_outlined,
      'totalWorkloadHours': Icons.access_time_outlined,
      'estimatedCost': Icons.euro_outlined,
      'resources': Icons.groups_outlined,
      'resourceCount': Icons.assignment_ind_outlined,
      'resourceGroupCount': Icons.group_work_outlined,
      'overloadedResourceCount': Icons.warning_amber_outlined,
    };

    return icons[key] ?? Icons.info_outline;
  }

  String _fallbackLabel(String key) {
    final formatted = key
        .replaceAllMapped(
          RegExp(r'([A-Z])'),
          (match) => ' ${match.group(1)}',
        )
        .trim();

    if (formatted.isEmpty) return key;

    return formatted[0].toUpperCase() + formatted.substring(1);
  }

  String _formatValue(String key, dynamic value) {
    if (value == null) return '-';

    if (value is String) {
      final parsedDate = DateTime.tryParse(value);

      if (parsedDate != null && value.contains('T')) {
        return _formatDate(parsedDate);
      }

      return value;
    }

    if (value is DateTime) {
      return _formatDate(value);
    }

    if (value is num) {
      if (key == 'totalWorkloadHours') {
        return '${_formatNumber(value)} h';
      }

      if (key == 'estimatedCost') {
        return '${_formatNumber(value)} €';
      }

      return _formatNumber(value);
    }

    if (value is List) {
      return '${value.length} élément(s)';
    }

    if (value is Map) {
      return '${value.length} champ(s)';
    }

    return value.toString();
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year.toString();

    return '$day/$month/$year';
  }

  String _formatNumber(num value) {
    if (value % 1 == 0) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(1);
  }
}

class _ResourceAnalysisDisplayItem {
  final String label;
  final String value;
  final IconData icon;

  const _ResourceAnalysisDisplayItem({
    required this.label,
    required this.value,
    required this.icon,
  });
}

class _ResourceAnalysisItem extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _ResourceAnalysisItem({
    required this.label,
    required this.value,
    required this.icon,
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
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}