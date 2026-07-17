import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Shown when gallery access is denied — explains what to do, in the app's
/// voice, and offers the two ways forward.
class PermissionView extends StatelessWidget {
  const PermissionView({
    super.key,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.image_not_supported_outlined,
                size: 44, color: AppColors.muted),
            const SizedBox(height: 20),
            Text(
              'swipedel needs your gallery',
              textAlign: TextAlign.center,
              style: AppTheme.display(context, size: 22),
            ),
            const SizedBox(height: 10),
            Text(
              'Grant access to your photos and videos to start sorting them.',
              textAlign: TextAlign.center,
              style: AppTheme.body(context, size: 14, color: AppColors.muted),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.mist,
                foregroundColor: AppColors.ink,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
              ),
              child: Text(
                'Grant access',
                style: AppTheme.body(
                    context, size: 15, weight: FontWeight.w600,
                    color: AppColors.ink),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: onOpenSettings,
              child: Text(
                'Open settings',
                style:
                    AppTheme.body(context, size: 14, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
