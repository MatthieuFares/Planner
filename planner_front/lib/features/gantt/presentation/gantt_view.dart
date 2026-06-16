import 'package:flutter/material.dart';

import 'structured_gantt_view.dart';

class GanttView extends StatelessWidget {
  final int projectId;

  const GanttView({
    super.key,
    required this.projectId,
  });

  @override
  Widget build(BuildContext context) {
    return StructuredGanttView(projectId: projectId);
  }
}