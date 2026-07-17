import 'package:flutter/material.dart';

import '../services/favorites_service.dart';
import '../theme/app_theme.dart';

/// A heart toggle bound to [favorites]. Rebuilds itself when the favorite set
/// changes, so every instance for the same asset stays in sync.
class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.assetId,
    this.size = 22,
    this.onSurface = false,
  });

  final String assetId;

  /// Icon size.
  final double size;

  /// When true, sits on a chrome surface (viewer top bar) — no scrim disc.
  final bool onSurface;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: favorites,
      builder: (context, _) {
        final active = favorites.isFavorite(assetId);
        final icon = Icon(
          active ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          size: size,
          color: active ? AppColors.rose : AppColors.mist,
        );
        return IconButton(
          onPressed: () => favorites.toggle(assetId),
          tooltip: active ? 'Remove favorite' : 'Add favorite',
          style: onSurface
              ? null
              : IconButton.styleFrom(
                  backgroundColor: Colors.black.withValues(alpha: 0.42),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(999),
                    side: const BorderSide(color: AppColors.line),
                  ),
                ),
          icon: icon,
        );
      },
    );
  }
}
