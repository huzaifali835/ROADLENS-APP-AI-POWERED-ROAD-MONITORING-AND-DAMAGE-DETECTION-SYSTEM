import 'package:flutter/material.dart';

import '../constants/app_constants.dart';

class ResponsiveContent extends StatelessWidget {
  const ResponsiveContent({
    required this.child,
    this.maxWidth = AppConstants.maxContentWidth,
    this.padding = const EdgeInsets.symmetric(
      horizontal: AppConstants.pagePadding,
    ),
    super.key,
  });

  final Widget child;
  final double maxWidth;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}
