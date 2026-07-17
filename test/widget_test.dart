import 'package:flutter_test/flutter_test.dart';
import 'package:swipedel/utils/formatters.dart';

void main() {
  group('humanFileSize', () {
    test('handles null and non-positive', () {
      expect(humanFileSize(null), '—');
      expect(humanFileSize(0), '—');
    });

    test('formats bytes, KB, MB', () {
      expect(humanFileSize(512), '512 B');
      expect(humanFileSize(1024), '1 KB');
      expect(humanFileSize(1536), '1.5 KB');
      expect(humanFileSize(4404019), '4.2 MB');
    });
  });

  group('formatDuration', () {
    test('minutes:seconds and hours', () {
      expect(formatDuration(const Duration(seconds: 64)), '1:04');
      expect(formatDuration(const Duration(hours: 1, minutes: 2, seconds: 7)),
          '1:02:07');
      expect(formatDuration(Duration.zero), '0:00');
    });
  });

  group('formatCounter', () {
    test('zero-pads to the total width', () {
      expect(formatCounter(12, 340), '012 / 340');
      expect(formatCounter(1, 9), '1 / 9');
    });
  });

  group('formatDate', () {
    test('null falls back to em dash', () {
      expect(formatDate(null), '—');
    });
  });
}
