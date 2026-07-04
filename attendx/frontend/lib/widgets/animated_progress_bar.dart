import 'package:flutter/material.dart';

/// Smoothly animates between percentage values; color-coded by status.
class AnimatedProgressBar extends StatelessWidget {
  final double percentage; // 0-100
  final Color color;
  final double height;

  const AnimatedProgressBar({
    super.key,
    required this.percentage,
    required this.color,
    this.height = 10,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = percentage.clamp(0, 100) / 100;
    return ClipRRect(
      borderRadius: BorderRadius.circular(height),
      child: Container(
        height: height,
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Align(
          alignment: Alignment.centerLeft,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: clamped.toDouble()),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) {
              return FractionallySizedBox(
                widthFactor: value,
                child: Container(color: color),
              );
            },
          ),
        ),
      ),
    );
  }
}
