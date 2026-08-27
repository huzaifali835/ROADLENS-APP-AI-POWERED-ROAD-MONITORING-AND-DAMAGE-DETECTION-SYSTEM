import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.onTap,
    this.color,
    this.borderColor,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(padding: padding, child: child);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppConstants.radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: color ?? theme.colorScheme.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppConstants.radius),
          side: BorderSide(
            color: borderColor ?? theme.colorScheme.outlineVariant,
          ),
        ),
        child: onTap == null
            ? content
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(AppConstants.radius),
                child: content,
              ),
      ),
    );
  }
}
