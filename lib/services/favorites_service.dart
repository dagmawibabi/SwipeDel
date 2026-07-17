import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Stores which media items the user has favorited, persisted across launches.
///
/// A single shared instance ([favorites]) so every heart button and the
/// Favorites screen stay in sync. Order is preserved newest-first (most
/// recently favorited at the front).
class FavoritesService extends ChangeNotifier {
  FavoritesService._();

  static const _key = 'favorite_asset_ids';

  /// Insertion-ordered; front = most recently favorited.
  final List<String> _ids = [];
  bool _loaded = false;

  List<String> get ids => List.unmodifiable(_ids);
  int get count => _ids.length;

  bool isFavorite(String id) => _ids.contains(id);

  /// Load persisted favorites. Safe to call more than once.
  Future<void> load() async {
    if (_loaded) return;
    final prefs = await SharedPreferences.getInstance();
    _ids
      ..clear()
      ..addAll(prefs.getStringList(_key) ?? const []);
    _loaded = true;
    notifyListeners();
  }

  /// Flip the favorite state of [id] and persist. Returns the new state.
  Future<bool> toggle(String id) async {
    final nowFavorite = !_ids.contains(id);
    if (nowFavorite) {
      _ids.insert(0, id);
    } else {
      _ids.remove(id);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, _ids);
    return nowFavorite;
  }
}

/// App-wide favorites store.
final favorites = FavoritesService._();
