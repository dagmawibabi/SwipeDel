import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import 'favorite_button.dart';
import 'spec_strip.dart';

/// A single swipe card: media thumbnail filling a rounded surface, with the
/// spec strip pinned to the bottom and a play badge for videos.
class MediaCard extends StatefulWidget {
  const MediaCard({
    super.key,
    required this.asset,
    required this.service,
  });

  final AssetEntity asset;
  final GalleryService service;

  @override
  State<MediaCard> createState() => _MediaCardState();
}

/// Process-lifetime caches so a card that shifts position (or is revisited)
/// paints its thumbnail immediately instead of flashing a spinner.
final Map<String, Uint8List> _thumbCache = {};
final Map<String, int> _sizeCache = {};

class _MediaCardState extends State<MediaCard> {
  Uint8List? _thumb;
  int? _sizeBytes;

  bool get _isVideo => widget.asset.type == AssetType.video;

  @override
  void initState() {
    super.initState();
    _seedFromCache();
    _load();
  }

  @override
  void didUpdateWidget(covariant MediaCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id) {
      _seedFromCache();
      _load();
    }
  }

  void _seedFromCache() {
    // Keep the old frame if the new asset isn't cached, to avoid a blank flash.
    final cachedThumb = _thumbCache[widget.asset.id];
    if (cachedThumb != null) _thumb = cachedThumb;
    _sizeBytes = _sizeCache[widget.asset.id];
  }

  Future<void> _load() async {
    final asset = widget.asset;
    if (_thumbCache[asset.id] == null) {
      final thumb = await asset.thumbnailDataWithSize(
        const ThumbnailSize(720, 1080),
        quality: 88,
      );
      if (thumb != null) _thumbCache[asset.id] = thumb;
      if (mounted && asset.id == widget.asset.id) {
        setState(() => _thumb = thumb);
      }
    }
    if (_sizeCache[asset.id] == null) {
      final size = await widget.service.fileSize(asset);
      if (size != null) _sizeCache[asset.id] = size;
      if (mounted && asset.id == widget.asset.id) {
        setState(() => _sizeBytes = size);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 30,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_thumb != null)
            Image.memory(_thumb!, fit: BoxFit.cover, gaplessPlayback: true)
          else
            const Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.muted,
                ),
              ),
            ),

          // Bottom scrim so the spec strip stays legible over any image.
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.center,
                colors: [Color(0xCC000000), Color(0x00000000)],
              ),
            ),
          ),

          if (_isVideo) const _PlayBadge(),

          Positioned(
            top: 12,
            right: 12,
            child: FavoriteButton(assetId: widget.asset.id),
          ),

          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SpecStrip(
              sizeBytes: _sizeBytes,
              date: widget.asset.createDateTime,
              isVideo: _isVideo,
              duration: _isVideo ? widget.asset.videoDuration : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _PlayBadge extends StatelessWidget {
  const _PlayBadge();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.45),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.mist.withValues(alpha: 0.85)),
        ),
        child: const Icon(Icons.play_arrow_rounded, color: AppColors.mist, size: 36),
      ),
    );
  }
}
