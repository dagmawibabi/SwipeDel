import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/favorites_service.dart';
import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import '../widgets/empty_view.dart';
import '../widgets/favorite_button.dart';
import 'viewer_screen.dart';

/// A grid of every media item the user has favorited, newest first.
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key, required this.service});

  final GalleryService service;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Favorites', style: AppTheme.display(context, size: 20)),
      ),
      body: SafeArea(
        top: false,
        child: AnimatedBuilder(
          animation: favorites,
          builder: (context, _) {
            final ids = favorites.ids;
            if (ids.isEmpty) {
              return const EmptyView(
                icon: Icons.favorite_border_rounded,
                title: 'No favorites yet',
                message: 'Tap the heart on any photo or video to save it here.',
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
              ),
              itemCount: ids.length,
              itemBuilder: (context, index) => _FavoriteTile(
                key: ValueKey(ids[index]),
                assetId: ids[index],
                service: service,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _FavoriteTile extends StatefulWidget {
  const _FavoriteTile({
    super.key,
    required this.assetId,
    required this.service,
  });

  final String assetId;
  final GalleryService service;

  @override
  State<_FavoriteTile> createState() => _FavoriteTileState();
}

class _FavoriteTileState extends State<_FavoriteTile> {
  AssetEntity? _asset;
  Uint8List? _thumb;
  bool _missing = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final asset = await AssetEntity.fromId(widget.assetId);
    if (asset == null) {
      if (mounted) setState(() => _missing = true);
      return;
    }
    final thumb =
        await asset.thumbnailDataWithSize(const ThumbnailSize(300, 300));
    if (!mounted) return;
    setState(() {
      _asset = asset;
      _thumb = thumb;
    });
  }

  void _open() {
    final asset = _asset;
    if (asset == null) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewerScreen(asset: asset, service: widget.service),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _open,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: AppColors.surface,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_thumb != null)
                Image.memory(_thumb!, fit: BoxFit.cover, gaplessPlayback: true)
              else
                Center(
                  child: Icon(
                    _missing ? Icons.image_not_supported_outlined : null,
                    color: AppColors.muted,
                    size: 20,
                  ),
                ),
              if (_asset?.type == AssetType.video)
                const Positioned(
                  left: 6,
                  bottom: 6,
                  child: Icon(Icons.play_circle_fill_rounded,
                      color: AppColors.mist, size: 20),
                ),
              Positioned(
                top: -6,
                right: -6,
                child: FavoriteButton(assetId: widget.assetId, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
