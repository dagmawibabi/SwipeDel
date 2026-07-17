import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/album_progress_service.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';

/// A grid tile for one album: cover thumbnail, name, and item count.
class AlbumTile extends StatefulWidget {
  const AlbumTile({
    super.key,
    required this.album,
    required this.count,
    required this.service,
    required this.onTap,
  });

  final AssetPathEntity album;

  /// Item count for the active filter (fetched by the parent).
  final int count;
  final GalleryService service;
  final VoidCallback onTap;

  @override
  State<AlbumTile> createState() => _AlbumTileState();
}

class _AlbumTileState extends State<AlbumTile> {
  Uint8List? _cover;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant AlbumTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.album.id != widget.album.id) {
      _cover = null;
      _load();
    }
  }

  Future<void> _load() async {
    final cover = await widget.service.coverAsset(widget.album);
    final bytes = await cover?.thumbnailDataWithSize(
      const ThumbnailSize(400, 400),
    );
    if (!mounted) return;
    setState(() => _cover = bytes);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadii.tile),
                border: Border.all(color: AppColors.line),
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (_cover == null)
                    const _CoverPlaceholder()
                  else
                    Image.memory(
                      _cover!,
                      fit: BoxFit.cover,
                      gaplessPlayback: true,
                    ),
                  AnimatedBuilder(
                    animation: albumProgress,
                    builder: (context, _) {
                      if (albumProgress.isCompleted(widget.album.id)) {
                        return const _CompletedBadge();
                      }
                      final p = albumProgress.progressFor(widget.album.id);
                      if (p != null && p.inProgress) {
                        return _ProgressBadge(fraction: p.fraction);
                      }
                      return const SizedBox.shrink();
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            widget.album.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.display(context, size: 15, weight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            '${widget.count} item${widget.count == 1 ? '' : 's'}',
            style: AppTheme.mono(context, size: 11, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _CoverPlaceholder extends StatelessWidget {
  const _CoverPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(Icons.photo_library_outlined, color: AppColors.muted, size: 28),
    );
  }
}

/// Corner badge with a ring + percentage for a partially-swiped album.
class _ProgressBadge extends StatelessWidget {
  const _ProgressBadge({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final pct = (fraction * 100).round();
    return Positioned(
      top: 8,
      left: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(AppRadii.pill),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 13,
              height: 13,
              child: CircularProgressIndicator(
                value: fraction,
                strokeWidth: 2,
                backgroundColor: AppColors.line,
                valueColor: const AlwaysStoppedAnimation(AppColors.teal),
              ),
            ),
            const SizedBox(width: 6),
            Text('$pct%',
                style: AppTheme.mono(context, size: 11, color: AppColors.mist)),
          ],
        ),
      ),
    );
  }
}

/// Corner mark shown on an album the user has swiped all the way through.
class _CompletedBadge extends StatelessWidget {
  const _CompletedBadge();

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Faint tint so a finished album reads as "done" at a glance.
        DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.ink.withValues(alpha: 0.28),
          ),
        ),
        Positioned(
          top: 8,
          left: 8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.teal,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.check_rounded, size: 13, color: AppColors.ink),
                SizedBox(width: 3),
                Text(
                  'Done',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
