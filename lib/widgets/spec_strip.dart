import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/formatters.dart';

/// The signature element: file metadata as precise monospace pills.
///
/// Purely presentational — parents fetch the byte size and pass it in so the
/// strip never triggers file reads during rebuilds.
class SpecStrip extends StatelessWidget {
  const SpecStrip({
    super.key,
    required this.sizeBytes,
    required this.date,
    this.isVideo = false,
    this.duration,
    this.dimensions,
  });

  /// Byte size, or null while still loading / unavailable.
  final int? sizeBytes;
  final DateTime? date;
  final bool isVideo;
  final Duration? duration;

  /// Optional `WxH` pixel dimensions (shown in the viewer overlay).
  final Size? dimensions;

  @override
  Widget build(BuildContext context) {
    final pills = <Widget>[
      _Pill(
        icon: Icons.calendar_today_outlined,
        label: formatDate(date),
      ),
      _Pill(
        icon: Icons.data_usage_outlined,
        label: sizeBytes == null ? '···' : humanFileSize(sizeBytes),
      ),
      if (isVideo)
        _Pill(
          icon: Icons.play_arrow_rounded,
          label: formatDuration(duration),
          accent: AppColors.teal,
        ),
      if (dimensions != null)
        _Pill(
          icon: Icons.aspect_ratio_outlined,
          label: '${dimensions!.width.toInt()}×${dimensions!.height.toInt()}',
        ),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: pills,
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    required this.icon,
    required this.label,
    this.accent,
  });

  final IconData icon;
  final String label;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final color = accent ?? AppColors.mist;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppRadii.pill),
        border: Border.all(color: AppColors.line),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: accent ?? AppColors.muted),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTheme.mono(context, size: 12, color: color),
          ),
        ],
      ),
    );
  }
}
