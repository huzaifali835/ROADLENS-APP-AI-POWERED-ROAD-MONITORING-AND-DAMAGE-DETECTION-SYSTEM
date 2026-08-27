import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({this.onDark = false, this.compact = false, super.key});

  final bool onDark;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark
        ? Colors.white
        : Theme.of(context).colorScheme.onSurface;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: compact ? 38 : 48,
          height: compact ? 38 : 48,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [AppColors.primary, AppColors.accent],
            ),
            borderRadius: BorderRadius.circular(compact ? 12 : 15),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.24),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(
            Icons.center_focus_strong_rounded,
            color: Colors.white,
            size: compact ? 23 : 29,
          ),
        ),
        const SizedBox(width: 12),
        Flexible(
          fit: FlexFit.loose,
          child: Text(
            'StreetLens',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
          ),
        ),
      ],
    );
  }
}
