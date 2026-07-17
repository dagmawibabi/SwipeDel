import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How far the user has gotten through one album.
class AlbumProgress {
  const AlbumProgress({
    required this.reviewed,
    required this.total,
    required this.completed,
    this.nextId,
  });

  /// Items swiped through that still exist.
  final int reviewed;

  /// Album size at the time of the last save.
  final int total;

  /// True once the user has reached the end at least once.
  final bool completed;

  /// Id of the next unreviewed item — the resume anchor.
  final String? nextId;

  /// 0..1 fraction reviewed.
  double get fraction =>
      total <= 0 ? 0 : (reviewed / total).clamp(0.0, 1.0).toDouble();

  /// In progress but not finished — the case that shows a ring.
  bool get inProgress => !completed && reviewed > 0 && reviewed < total;

  Map<String, dynamic> toJson() => {
        'r': reviewed,
        't': total,
        'c': completed,
        'n': nextId,
      };

  factory AlbumProgress.fromJson(Map<String, dynamic> j) => AlbumProgress(
        reviewed: (j['r'] as num?)?.toInt() ?? 0,
        total: (j['t'] as num?)?.toInt() ?? 0,
        completed: (j['c'] as bool?) ?? false,
        nextId: j['n'] as String?,
      );
}

/// Tracks per-album swipe progress (position + completion), persisted across
/// launches. A single shared instance ([albumProgress]) so album tiles update
/// live when you leave a deck.
class AlbumProgressService extends ChangeNotifier {
  AlbumProgressService._();

  static const _key = 'album_progress_v2';

  final Map<String, AlbumProgress> _map = {};
  bool _loaded = false;

  AlbumProgress? progressFor(String albumId) => _map[albumId];
  bool isCompleted(String albumId) => _map[albumId]?.completed ?? false;

  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    _map.clear();
    for (final s in raw) {
      final j = jsonDecode(s) as Map<String, dynamic>;
      final id = j['id'] as String?;
      if (id != null) _map[id] = AlbumProgress.fromJson(j);
    }
    _loaded = true;
    notifyListeners();
  }

  /// Record where the user left off in an album.
  Future<void> save(
    String albumId, {
    required int reviewed,
    required int total,
    required bool completed,
    String? nextId,
  }) async {
    _map[albumId] = AlbumProgress(
      reviewed: reviewed.clamp(0, total < 0 ? 0 : total),
      total: total < 0 ? 0 : total,
      completed: completed,
      nextId: nextId,
    );
    notifyListeners();
    await _persist();
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _key,
      _map.entries
          .map((e) => jsonEncode({'id': e.key, ...e.value.toJson()}))
          .toList(),
    );
  }
}

/// App-wide album-progress store.
final albumProgress = AlbumProgressService._();
