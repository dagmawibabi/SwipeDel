import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Directional glow drawn over a card while it is being dragged: rose "Delete"
/// when dragging left, teal "Keep" when dragging right.
class SwipeOverlay extends StatelessWidget {
  const SwipeOverlay({super.key, required this.percentX});

  /// Horizontal drag amount, roughly -1 (full left) .. 1 (full right).
  final double percentX;

  @override
  Widget build(BuildContext context) {
    final magnitude = percentX.abs().clamp(0.0, 1.0);
    if (magnitude < 0.02) return const SizedBox.shrink();

    final draggingRight = percentX > 0;
    final color = draggingRight ? AppColors.teal : AppColors.rose;
    final opacity = (magnitude * 1.4).clamp(0.0, 1.0);

    return IgnorePointer(
      child: Opacity(
        opacity: opacity,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: color, width: 3),
            gradient: LinearGradient(
              begin: draggingRight
                  ? Alignment.centerRight
                  : Alignment.centerLeft,
              end: Alignment.center,
              colors: [color.withValues(alpha: 0.35), Colors.transparent],
            ),
          ),
          child: Align(
            alignment: draggingRight
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    draggingRight
                        ? Icons.check_rounded
                        : Icons.delete_outline_rounded,
                    color: color,
                    size: 44,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    draggingRight ? 'KEEP' : 'DELETE',
                    style: TextStyle(
                      color: color,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
