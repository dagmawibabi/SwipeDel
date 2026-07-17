import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../services/favorites_service.dart';
import '../services/gallery_service.dart';
import '../services/trash_service.dart';
import '../theme/app_theme.dart';
import '../widgets/album_tile.dart';
import '../widgets/empty_view.dart';
import '../widgets/help_dialog.dart';
import '../widgets/permission_view.dart';
import 'favorites_screen.dart';
import 'swipe_screen.dart';
import 'trash_screen.dart';

/// Home screen: permission gate, then a grid of the device's albums.
class AlbumsScreen extends StatefulWidget {
  const AlbumsScreen({super.key});

  @override
  State<AlbumsScreen> createState() => _AlbumsScreenState();
}

enum _Status { loading, denied, ready }

class _AlbumsScreenState extends State<AlbumsScreen> {
  final _service = const GalleryService();

  _Status _status = _Status.loading;
  GalleryAccess _access = GalleryAccess.denied;
  MediaFilter _filter = MediaFilter.all;

  /// Albums for the active filter, paired with their (pre-fetched) counts.
  /// Empty albums are excluded so a filter never shows "0 items" tiles.
  List<({AssetPathEntity album, int count})> _albums = const [];
  bool _gridLoading = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    setState(() => _status = _Status.loading);
    final access = await _service.requestPermission();
    if (!mounted) return;
    if (access == GalleryAccess.denied) {
      setState(() {
        _access = access;
        _status = _Status.denied;
      });
      return;
    }
    _access = access;
    await _loadAlbums();
    if (!mounted) return;
    setState(() => _status = _Status.ready);
    _maybeShowFirstRunHelp();
  }

  static const _helpSeenKey = 'help_seen_v1';

  Future<void> _maybeShowFirstRunHelp() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_helpSeenKey) ?? false) return;
    await prefs.setBool(_helpSeenKey, true);
    if (!mounted) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showHelpDialog(context, firstRun: true);
    });
  }

  Future<void> _loadAlbums() async {
    setState(() => _gridLoading = true);
    final paths = await _service.loadAlbums(_filter);
    final counts =
        await Future.wait(paths.map((p) => _service.albumCount(p)));
    final entries = <({AssetPathEntity album, int count})>[];
    for (var i = 0; i < paths.length; i++) {
      if (counts[i] > 0) entries.add((album: paths[i], count: counts[i]));
    }
    if (!mounted) return;
    setState(() {
      _albums = entries;
      _gridLoading = false;
    });
  }

  void _onFilterChanged(MediaFilter filter) {
    if (filter == _filter) return;
    setState(() => _filter = filter);
    _loadAlbums();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(child: _buildBody()),
    );
  }

  Widget _buildBody() {
    switch (_status) {
      case _Status.loading:
        return const _LoadingList();
      case _Status.denied:
        return _DeniedList(
          onRetry: _init,
          onOpenSettings: () async {
            await _service.openSettings();
          },
        );
      case _Status.ready:
        return _buildReady();
    }
  }

  /// Fixed header + filter, with only the album grid scrolling beneath them.
  Widget _buildReady() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(),
        if (_access == GalleryAccess.limited) _limitedBanner(),
        _SegmentedFilter(selected: _filter, onChanged: _onFilterChanged),
        Expanded(
          child: RefreshIndicator(
            color: AppColors.teal,
            backgroundColor: AppColors.surface,
            onRefresh: _init,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [_buildGridBody()],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGridBody() {
    if (_gridLoading) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: Center(
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.muted),
        ),
      );
    }
    if (_albums.isEmpty) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: EmptyView(
          icon: switch (_filter) {
            MediaFilter.photos => Icons.photo_outlined,
            MediaFilter.videos => Icons.videocam_outlined,
            MediaFilter.all => Icons.photo_library_outlined,
          },
          title: switch (_filter) {
            MediaFilter.photos => 'No photos here',
            MediaFilter.videos => 'No videos here',
            MediaFilter.all => 'No albums yet',
          },
          message: 'Try a different filter, or add media to your phone.',
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisSpacing: 22,
          crossAxisSpacing: 16,
          childAspectRatio: 0.82,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final entry = _albums[index];
            return AlbumTile(
              key: ValueKey(entry.album.id),
              album: entry.album,
              count: entry.count,
              service: _service,
              onTap: () => _openAlbum(entry.album),
            );
          },
          childCount: _albums.length,
        ),
      ),
    );
  }

  Widget _header() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'SwipeDel',
                  style: AppTheme.display(context,
                      size: 32, weight: FontWeight.w700, letterSpacing: -0.5),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap an album to begin',
                  style:
                      AppTheme.body(context, size: 14, color: AppColors.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _CircleIconButton(
            icon: Icons.help_outline_rounded,
            tooltip: 'Help',
            onTap: () => showHelpDialog(context),
          ),
          const SizedBox(width: 8),
          _TrashButton(onTap: _openTrash),
          const SizedBox(width: 8),
          _FavoritesChip(onTap: _openFavorites),
        ],
      ),
    );
  }

  void _openTrash() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const TrashScreen()),
    );
  }

  void _openFavorites() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FavoritesScreen(service: _service),
      ),
    );
  }

  Widget _limitedBanner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, size: 18, color: AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "You've shared only some items. Add more to see them here.",
                style:
                    AppTheme.body(context, size: 13, color: AppColors.muted),
              ),
            ),
            TextButton(
              onPressed: () async {
                await _service.manageLimitedAccess();
                await _init();
              },
              child: Text(
                'Manage',
                style: AppTheme.body(
                    context, size: 13, weight: FontWeight.w600,
                    color: AppColors.teal),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAlbum(AssetPathEntity album) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            SwipeScreen(album: album, filter: _filter, service: _service),
      ),
    );
  }
}

/// Round icon button styled to sit beside the favorites chip.
class _CircleIconButton extends StatelessWidget {
  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadii.pill),
        side: const BorderSide(color: AppColors.line),
      ),
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 20, color: AppColors.mist),
          ),
        ),
      ),
    );
  }
}

/// Trash shortcut with a live count badge.
class _TrashButton extends StatelessWidget {
  const _TrashButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: trashService,
      builder: (context, _) {
        final count = trashService.count;
        return Stack(
          clipBehavior: Clip.none,
          children: [
            _CircleIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: 'Trash',
              onTap: onTap,
            ),
            if (count > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  constraints: const BoxConstraints(minWidth: 18),
                  decoration: BoxDecoration(
                    color: AppColors.rose,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                    border: Border.all(color: AppColors.ink, width: 1.5),
                  ),
                  child: Text(
                    count > 99 ? '99+' : '$count',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Segmented All / Photos / Videos control for the media filter.
class _SegmentedFilter extends StatelessWidget {
  const _SegmentedFilter({required this.selected, required this.onChanged});

  final MediaFilter selected;
  final ValueChanged<MediaFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            for (final filter in MediaFilter.values)
              Expanded(child: _segment(context, filter)),
          ],
        ),
      ),
    );
  }

  Widget _segment(BuildContext context, MediaFilter filter) {
    final active = filter == selected;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(filter),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? AppColors.mist : Colors.transparent,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        alignment: Alignment.center,
        child: Text(
          filter.label,
          style: AppTheme.body(
            context,
            size: 13,
            weight: FontWeight.w600,
            color: active ? AppColors.ink : AppColors.muted,
          ),
        ),
      ),
    );
  }
}

/// Heart shortcut to the Favorites screen, badged with a live count.
class _FavoritesChip extends StatelessWidget {
  const _FavoritesChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: favorites,
      builder: (context, _) {
        final count = favorites.count;
        return Material(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: AppColors.line),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.favorite_rounded,
                      size: 16, color: AppColors.rose),
                  if (count > 0) ...[
                    const SizedBox(width: 6),
                    Text(
                      '$count',
                      style: AppTheme.mono(context, size: 13),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Simple shimmerless loading placeholder — a title and greyed tiles.
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        SizedBox(height: 120),
        Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.muted,
          ),
        ),
      ],
    );
  }
}

class _DeniedList extends StatelessWidget {
  const _DeniedList({required this.onRetry, required this.onOpenSettings});

  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return _ScrollableCenter(
      child: PermissionView(
        onRetry: onRetry,
        onOpenSettings: onOpenSettings,
      ),
    );
  }
}

/// Wraps a centered child so pull-to-refresh still works on full-screen states.
class _ScrollableCenter extends StatelessWidget {
  const _ScrollableCenter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }
}
