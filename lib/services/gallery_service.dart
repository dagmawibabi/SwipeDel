import 'package:photo_manager/photo_manager.dart';

/// Which kind of media to browse.
enum MediaFilter { all, photos, videos }

extension MediaFilterX on MediaFilter {
  RequestType get requestType => switch (this) {
        MediaFilter.all => RequestType.common,
        MediaFilter.photos => RequestType.image,
        MediaFilter.videos => RequestType.video,
      };

  String get label => switch (this) {
        MediaFilter.all => 'All',
        MediaFilter.photos => 'Photos',
        MediaFilter.videos => 'Videos',
      };
}

/// Ordering for the swipe deck.
enum DeckSort { newest, oldest, largest }

extension DeckSortX on DeckSort {
  String get label => switch (this) {
        DeckSort.newest => 'Newest first',
        DeckSort.oldest => 'Oldest first',
        DeckSort.largest => 'Largest first',
      };

  /// MediaStore/Photos column to order by.
  String get column => switch (this) {
        DeckSort.newest || DeckSort.oldest => CustomColumns.base.createDate,
        // Android byte-size column; ordered natively so we never read files.
        DeckSort.largest => '_size',
      };

  bool get ascending => this == DeckSort.oldest;
}

/// Result of asking for gallery access.
enum GalleryAccess {
  /// Full access to all media.
  granted,

  /// User picked a subset of media (Android 14+ / iOS limited).
  limited,

  /// No access.
  denied,
}

/// Thin wrapper over `photo_manager` for permission, albums, and assets.
class GalleryService {
  const GalleryService();

  /// Ask for gallery access, mapping the plugin state to our enum.
  Future<GalleryAccess> requestPermission() async {
    final state = await PhotoManager.requestPermissionExtend();
    switch (state) {
      case PermissionState.authorized:
        return GalleryAccess.granted;
      case PermissionState.limited:
        return GalleryAccess.limited;
      case PermissionState.denied:
      case PermissionState.notDetermined:
      case PermissionState.restricted:
        return GalleryAccess.denied;
    }
  }

  /// Albums for the given media [filter], newest content first.
  ///
  /// The returned [AssetPathEntity]s are scoped to [filter], so their counts,
  /// covers, and paged assets all reflect only that media type.
  Future<List<AssetPathEntity>> loadAlbums(MediaFilter filter) {
    final options = FilterOptionGroup(
      orders: [const OrderOption(type: OrderOptionType.createDate, asc: false)],
    );
    return PhotoManager.getAssetPathList(
      type: filter.requestType,
      filterOption: options,
    );
  }

  /// Number of items in an album.
  Future<int> albumCount(AssetPathEntity album) => album.assetCountAsync;

  /// The most recent asset in an album, used as its cover thumbnail.
  Future<AssetEntity?> coverAsset(AssetPathEntity album) async {
    final assets = await album.getAssetListRange(start: 0, end: 1);
    return assets.isEmpty ? null : assets.first;
  }

  /// A page of assets from an album for lazy loading of large albums.
  Future<List<AssetEntity>> loadAssets(
    AssetPathEntity album, {
    int page = 0,
    int size = 80,
  }) {
    return album.getAssetListPaged(page: page, size: size);
  }

  /// All of an album's assets in the given [sort] order, filtered by [filter].
  ///
  /// Ordering is done by the media database (via [AdvancedCustomFilter]), so
  /// even "largest first" never reads files — it's a column sort.
  Future<List<AssetEntity>> loadAssetsSorted(
    AssetPathEntity album,
    MediaFilter filter,
    DeckSort sort, {
    required int count,
  }) async {
    final ordered = AdvancedCustomFilter()
        .addOrderBy(column: sort.column, isAsc: sort.ascending);
    final paths = await PhotoManager.getAssetPathList(
      type: filter.requestType,
      filterOption: ordered,
    );
    AssetPathEntity? match;
    for (final p in paths) {
      if (p.id == album.id) {
        match = p;
        break;
      }
    }
    final source = match ?? album;
    return source.getAssetListPaged(page: 0, size: count <= 0 ? 1 : count);
  }

  /// Byte size of an asset's underlying file, or null if unavailable.
  ///
  /// Reads the origin file, so call it lazily (one card at a time), not for a
  /// whole album at once.
  Future<int?> fileSize(AssetEntity asset) async {
    final file = await asset.originFile;
    if (file == null) return null;
    try {
      return await file.length();
    } catch (_) {
      return null;
    }
  }

  /// Move assets to the device's recoverable trash (Android 11+ / API 30).
  ///
  /// Shows a system confirmation dialog, then returns the ids actually
  /// trashed — empty if the user cancels. Trashed items land in the OS
  /// "Recently deleted" and are auto-purged after ~30 days, so this is never a
  /// permanent delete.
  Future<List<String>> moveToTrash(List<AssetEntity> assets) {
    return PhotoManager.editor.android.moveToTrash(assets);
  }

  /// Open the OS settings page for this app (for a denied permission).
  Future<void> openSettings() => PhotoManager.openSetting();

  /// Re-present the limited-access picker (Android 14+ / iOS).
  Future<void> manageLimitedAccess() => PhotoManager.presentLimited();
}
