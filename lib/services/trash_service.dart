import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One item swipedel has moved to the device trash.
///
/// Android hides trashed media from normal queries and offers no un-trash, so
/// we snapshot what we need to display the item (a cached thumbnail + a little
/// metadata) at the moment we trash it.
class TrashRecord {
  const TrashRecord({
    required this.id,
    required this.name,
    required this.dateMillis,
    required this.isVideo,
    required this.durationSeconds,
    required this.trashedAtMillis,
  });

  final String id;
  final String name;
  final int dateMillis;
  final bool isVideo;
  final int durationSeconds;
  final int trashedAtMillis;

  DateTime get date => DateTime.fromMillisecondsSinceEpoch(dateMillis);
  Duration get duration => Duration(seconds: durationSeconds);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'date': dateMillis,
        'video': isVideo,
        'dur': durationSeconds,
        'trashedAt': trashedAtMillis,
      };

  factory TrashRecord.fromJson(Map<String, dynamic> j) => TrashRecord(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? '',
        dateMillis: (j['date'] as num?)?.toInt() ?? 0,
        isVideo: (j['video'] as bool?) ?? false,
        durationSeconds: (j['dur'] as num?)?.toInt() ?? 0,
        trashedAtMillis: (j['trashedAt'] as num?)?.toInt() ?? 0,
      );
}

/// Persisted store of items swipedel sent to the trash, newest first.
class TrashService extends ChangeNotifier {
  TrashService._();

  static const _key = 'trash_records_v1';

  /// Native channel that addresses already-trashed items directly (see
  /// android/.../MainActivity.kt). photo_manager can't reach trashed media.
  static const _channel = MethodChannel('swipedel/trash');

  final List<TrashRecord> _records = [];
  bool _loaded = false;
  Directory? _thumbDir;

  List<TrashRecord> get records => List.unmodifiable(_records);
  int get count => _records.length;

  /// On-disk path of the cached thumbnail for [id].
  String thumbPath(String id) => '${_thumbDir!.path}/$id.jpg';

  Future<Directory> _ensureThumbDir() async {
    if (_thumbDir != null) return _thumbDir!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory('${support.path}/trash_thumbs');
    if (!dir.existsSync()) dir.createSync(recursive: true);
    _thumbDir = dir;
    return dir;
  }

  Future<void> load() async {
    if (_loaded) return;
    await _ensureThumbDir();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    _records
      ..clear()
      ..addAll(raw.map((s) =>
          TrashRecord.fromJson(jsonDecode(s) as Map<String, dynamic>)));
    _loaded = true;
    notifyListeners();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      _records.map((r) => jsonEncode(r.toJson())).toList(),
    );
  }

  /// Record a freshly-trashed item: writes its thumbnail to disk and prepends
  /// it to the list. [thumb] should be captured *before* trashing, while the
  /// asset is still readable.
  Future<void> add(TrashRecord record, Uint8List? thumb) async {
    await _ensureThumbDir();
    if (thumb != null) {
      try {
        await File(thumbPath(record.id)).writeAsBytes(thumb, flush: true);
      } catch (_) {/* a missing thumb just shows a placeholder */}
    }
    _records.removeWhere((r) => r.id == record.id);
    _records.insert(0, record);
    notifyListeners();
    await _persist();
  }

  /// Permanently delete [ids] from the device (shows the OS delete dialog),
  /// then drop the ones actually deleted from the store. Returns deleted ids.
  Future<List<String>> permanentlyDelete(List<String> ids) =>
      _act('deleteForever', ids, dropThumbs: true);

  /// Restore [ids] out of the trash (shows the OS confirm dialog), then drop
  /// them from the store. Returns restored ids.
  Future<List<String>> restore(List<String> ids) =>
      _act('restore', ids, dropThumbs: true);

  Future<List<String>> _act(
    String method,
    List<String> ids, {
    required bool dropThumbs,
  }) async {
    if (ids.isEmpty) return const [];
    // Preserve id/type alignment for the native side.
    final targets = _records.where((r) => ids.contains(r.id)).toList();
    if (targets.isEmpty) return const [];

    final result = await _channel.invokeMethod<List<Object?>>(method, {
      'ids': targets.map((r) => r.id).toList(),
      'videos': targets.map((r) => r.isVideo).toList(),
    });
    final done = (result ?? const []).cast<String>();
    if (done.isEmpty) return done;

    for (final id in done) {
      _records.removeWhere((r) => r.id == id);
      if (dropThumbs) {
        final f = File(thumbPath(id));
        if (f.existsSync()) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    }
    notifyListeners();
    await _persist();
    return done;
  }
}

/// App-wide trash store.
final trashService = TrashService._();
