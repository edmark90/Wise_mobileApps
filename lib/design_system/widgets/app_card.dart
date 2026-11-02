import 'package:flutter/material.dart';

/// Consistent card container used across all screens.
/// Provides clean background, rounded corners, subtle border, and soft shadow.
class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final double elevation;
  final BorderRadius borderRadius;
  final Color borderColor;
  final double borderWidth;
  final VoidCallback? onTap;

  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.elevation = 0,
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.borderColor = Colors.transparent,
    this.borderWidth = 0,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveBorder = borderWidth > 0
        ? Border.all(color: borderColor, width: borderWidth)
        : null;

    final boxDecoration = BoxDecoration(
      color: color,
      borderRadius: borderRadius,
      border: effectiveBorder,
      boxShadow: elevation > 0
          ? [
              BoxShadow(
                color: const Color(0x0A0F172A),
                blurRadius: elevation * 4,
                offset: Offset(0, elevation),
              ),
            ]
          : null,
    );

    if (onTap != null) {
      return Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        child: InkWell(
          borderRadius: borderRadius,
          onTap: onTap,
          child: Ink(
            padding: padding,
            decoration: boxDecoration,
            child: child,
          ),
        ),
      );
    }

    return Container(
      padding: padding,
      decoration: boxDecoration,
      child: child,
    );
  }
}
