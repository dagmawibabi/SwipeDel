import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A feature the help sheet explains.
class _HelpItem {
  const _HelpItem(this.icon, this.color, this.title, this.body);
  final IconData icon;
  final Color color;
  final String title;
  final String body;
}

const _items = <_HelpItem>[
  _HelpItem(Icons.swipe_left_rounded, AppColors.rose, 'Swipe left to delete',
      'The item is queued for deletion and leaves the deck. Nothing is removed '
      'until you finish the album.'),
  _HelpItem(Icons.swipe_right_rounded, AppColors.teal, 'Swipe right to keep',
      'Keeps the item and moves on to the next one.'),
  _HelpItem(Icons.undo_rounded, AppColors.mist, 'Undo a mis-swipe',
      'Tap Undo to bring back the last card — as many steps as you need.'),
  _HelpItem(Icons.delete_outline_rounded, AppColors.rose,
      'Deletes go to the Trash',
      'When you leave an album, queued items move to your phone\'s recoverable '
      'trash — restore them anytime within ~30 days.'),
  _HelpItem(Icons.favorite_rounded, AppColors.rose, 'Favorite anything',
      'Tap the heart on a card or in the viewer. Find them all under the heart '
      'in the top bar.'),
  _HelpItem(Icons.zoom_in_rounded, AppColors.mist, 'Tap to open',
      'Tap a card for fullscreen — pinch to zoom photos, or play videos with a '
      'scrubber.'),
  _HelpItem(Icons.tune_rounded, AppColors.teal, 'Filter by type',
      'Use All / Photos / Videos to sort just one kind of media at a time.'),
];

/// Shows the help/onboarding sheet. [firstRun] tweaks the heading for a warm
/// first-launch welcome versus an on-demand reference.
Future<void> showHelpDialog(BuildContext context, {bool firstRun = false}) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.7),
    builder: (context) => _HelpDialog(firstRun: firstRun),
  );
}

class _HelpDialog extends StatelessWidget {
  const _HelpDialog({required this.firstRun});

  final bool firstRun;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: AppColors.line),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    firstRun ? 'Welcome to swipedel' : 'How it works',
                    style: AppTheme.display(context,
                        size: 24, weight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Clean up your camera roll one swipe at a time.',
                    style: AppTheme.body(context,
                        size: 14, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                itemCount: _items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 16),
                itemBuilder: (context, i) => _HelpRow(item: _items[i]),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                onPressed: () => Navigator.of(context).pop(),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.mist,
                  foregroundColor: AppColors.ink,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: Text(
                  firstRun ? 'Start swiping' : 'Got it',
                  style: AppTheme.body(context,
                      size: 15, weight: FontWeight.w600, color: AppColors.ink),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpRow extends StatelessWidget {
  const _HelpRow({required this.item});

  final _HelpItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: item.color.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(11),
          ),
          child: Icon(item.icon, color: item.color, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                style: AppTheme.body(context,
                    size: 15, weight: FontWeight.w600),
              ),
              const SizedBox(height: 2),
              Text(
                item.body,
                style: AppTheme.body(context, size: 13, color: AppColors.muted),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
