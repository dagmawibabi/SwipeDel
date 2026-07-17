import 'package:intl/intl.dart';

/// Human-friendly formatters for the spec strip.

/// Turns a byte count into a compact size like `4.2 MB` or `812 KB`.
String humanFileSize(int? bytes) {
  if (bytes == null || bytes <= 0) return '—';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var size = bytes.toDouble();
  var unit = 0;
  while (size >= 1024 && unit < units.length - 1) {
    size /= 1024;
    unit++;
  }
  // No decimals for plain bytes; one decimal above that, trimmed when whole.
  if (unit == 0) return '${size.toInt()} ${units[unit]}';
  final rounded = size.toStringAsFixed(1);
  final trimmed = rounded.endsWith('.0')
      ? rounded.substring(0, rounded.length - 2)
      : rounded;
  return '$trimmed ${units[unit]}';
}

final _dateFormat = DateFormat('d MMM yyyy');

/// Formats a capture date like `18 Jul 2026`.
String formatDate(DateTime? date) {
  if (date == null) return '—';
  return _dateFormat.format(date);
}

/// Formats a video duration like `1:04` or `1:02:07`.
String formatDuration(Duration? duration) {
  if (duration == null || duration == Duration.zero) return '0:00';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  final ss = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    final mm = minutes.toString().padLeft(2, '0');
    return '$hours:$mm:$ss';
  }
  return '$minutes:$ss';
}

/// Zero-padded card counter like `012 / 340`.
String formatCounter(int current, int total) {
  final width = total.toString().length;
  return '${current.toString().padLeft(width, '0')} / $total';
}
