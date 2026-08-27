import 'package:flutter/material.dart';

import '../../data/models/detection.dart';
import '../constants/app_colors.dart';

Color severityColor(DetectionSeverity severity) => switch (severity) {
  DetectionSeverity.critical => AppColors.critical,
  DetectionSeverity.high => AppColors.high,
  DetectionSeverity.moderate => AppColors.moderate,
  DetectionSeverity.low => AppColors.low,
};

class SeverityBadge extends StatelessWidget {
  const SeverityBadge({
    required this.severity,
    this.compact = false,
    super.key,
  });

  final DetectionSeverity severity;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final color = severityColor(severity);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 9 : 11,
        vertical: compact ? 5 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        severity.label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}
