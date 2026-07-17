import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_card_swiper/flutter_card_swiper.dart';
import 'package:photo_manager/photo_manager.dart';

import '../services/album_progress_service.dart';
import '../services/favorites_service.dart';
import '../services/gallery_service.dart';
import '../services/trash_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/empty_view.dart';
import '../widgets/media_card.dart';
import '../widgets/swipe_overlay.dart';
import 'viewer_screen.dart';

/// The card deck for one album.
///
/// Swipe left to mark an item for deletion (it leaves the deck immediately),
/// swipe right to keep it. Left-marked items are collected and moved to the
/// device's recoverable trash in one batch when you leave the album, so Undo
/// can always bring a mis-swipe back instantly before anything is trashed.
class SwipeScreen extends StatefulWidget {
  const SwipeScreen({
    super.key,
    required this.album,
    required this.filter,
    required this.service,
  });

  final AssetPathEntity album;
  final MediaFilter filter;
  final GalleryService service;

  @override
  State<SwipeScreen> createState() => _SwipeScreenState();
}

class _SwipeScreenState extends State<SwipeScreen> {
  final _controller = CardSwiperController();

  List<AssetEntity> _assets = const [];
  bool _loading = true;
  DeckSort _sort = DeckSort.newest;

  /// Index of the card currently on top of the deck.
  int _topIndex = 0;

  /// Where the deck starts (resume anchor for the current order).
  int _startIndex = 0;
  bool _finished = false;
  bool _committing = false;

  /// Ids swiped left, queued for the device trash (not yet trashed).
  final Set<String> _pendingTrash = {};

  /// How many items were actually trashed this session (for progress math).
  int _committedTrashCount = 0;

  bool get _canUndo => _topIndex > _startIndex || _finished;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load({bool resume = true}) async {
    final count = await widget.service.albumCount(widget.album);
    final assets = await widget.service.loadAssetsSorted(
      widget.album,
      widget.filter,
      _sort,
      count: count,
    );

    var start = 0;
    if (resume) {
      final progress = albumProgress.progressFor(widget.album.id);
      if (progress != null && !progress.completed) {
        final id = progress.nextId;
        final idx = id == null ? -1 : assets.indexWhere((a) => a.id == id);
        start = idx >= 0 ? idx : progress.reviewed;
      }
    }
    if (start < 0 || start >= assets.length) start = 0;

    if (!mounted) return;
    setState(() {
      _assets = assets;
      _startIndex = start;
      _topIndex = start;
      _finished = false;
      _committedTrashCount = 0;
      _loading = false;
    });
  }

  bool _onSwipe(int previous, int? current, CardSwiperDirection direction) {
    setState(() {
      if (direction == CardSwiperDirection.left) {
        _pendingTrash.add(_assets[previous].id);
      }
      if (current == null) {
        _finished = true;
        _topIndex = _assets.length;
      } else {
        _topIndex = current;
      }
    });
    if (current == null) {
      _saveProgress();
    }
    return true;
  }

  bool _onUndo(int? previous, int current, CardSwiperDirection direction) {
    setState(() {
      _finished = false;
      _topIndex = current;
      if (direction == CardSwiperDirection.left) {
        _pendingTrash.remove(_assets[current].id);
      }
    });
    return true;
  }

  /// Persist where the user is in this album (position + completion), so the
  /// grid can show a progress ring and the deck can resume next time.
  void _saveProgress() {
    if (_assets.isEmpty) return;
    if (!(_topIndex > 0 || _finished)) return; // nothing meaningful to record
    final total = _assets.length - _committedTrashCount;
    final reviewed = (_finished ? _assets.length : _topIndex) - _committedTrashCount;
    final nextId =
        (_finished || _topIndex >= _assets.length) ? null : _assets[_topIndex].id;
    // Once an album has been finished, keep it marked done even on a re-review.
    final completed = _finished || albumProgress.isCompleted(widget.album.id);
    albumProgress.save(
      widget.album.id,
      reviewed: reviewed,
      total: total,
      completed: completed,
      nextId: nextId,
    );
  }

  Future<void> _pickSort() async {
    final chosen = await showModalBottomSheet<DeckSort>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Sort deck by',
                    style: AppTheme.display(context, size: 18)),
              ),
            ),
            for (final option in DeckSort.values)
              ListTile(
                leading: Icon(
                  option == _sort
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: option == _sort ? AppColors.teal : AppColors.muted,
                ),
                title: Text(option.label,
                    style: AppTheme.body(context, size: 15)),
                onTap: () => Navigator.of(context).pop(option),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) await _changeSort(chosen);
  }

  Future<void> _changeSort(DeckSort sort) async {
    if (sort == _sort) return;
    if (_pendingTrash.isNotEmpty) {
      final ok = await _confirmRestart();
      if (ok != true) return;
    }
    setState(() {
      _sort = sort;
      _loading = true;
      _pendingTrash.clear();
      _finished = false;
    });
    await _load(resume: false);
  }

  Future<bool?> _confirmRestart() {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.line),
        ),
        title: Text('Change sort?', style: AppTheme.display(context, size: 20)),
        content: Text(
          'This restarts the deck from the top and clears the '
          '${_pendingTrash.length} item${_pendingTrash.length == 1 ? '' : 's'} '
          'you\'ve queued to delete (nothing was trashed yet).',
          style: AppTheme.body(context, size: 14, color: AppColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel',
                style: AppTheme.body(context, size: 14, color: AppColors.muted)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.mist,
              foregroundColor: AppColors.ink,
            ),
            child: Text('Restart',
                style: AppTheme.body(context,
                    size: 14, weight: FontWeight.w600, color: AppColors.ink)),
          ),
        ],
      ),
    );
  }

  void _openViewer(int index) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ViewerScreen(
          asset: _assets[index],
          service: widget.service,
        ),
      ),
    );
  }

  /// Handle leaving the screen: if items are queued for trash, confirm first.
  Future<void> _handleBack() async {
    if (_pendingTrash.isEmpty) {
      _saveProgress();
      if (mounted) Navigator.of(context).pop();
      return;
    }
    final choice = await _showTrashSheet();
    if (choice == _ExitChoice.cancel || !mounted) return;
    if (choice == _ExitChoice.trash) {
      final committed = await _commitTrash();
      if (!committed || !mounted) return;
    }
    _saveProgress();
    if (mounted) Navigator.of(context).pop();
  }

  Future<_ExitChoice?> _showTrashSheet() {
    final count = _pendingTrash.length;
    return showModalBottomSheet<_ExitChoice>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Move $count item${count == 1 ? '' : 's'} to Trash?',
                  style: AppTheme.display(context, size: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  'They go to your phone\'s recoverable trash — restore them '
                  'anytime within ~30 days.',
                  style:
                      AppTheme.body(context, size: 14, color: AppColors.muted),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: () =>
                      Navigator.of(context).pop(_ExitChoice.trash),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.rose,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  label: Text('Move $count to Trash',
                      style: AppTheme.body(context,
                          size: 15,
                          weight: FontWeight.w600,
                          color: Colors.white)),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(_ExitChoice.keep),
                  child: Text('Keep all & leave',
                      style: AppTheme.body(context,
                          size: 14, color: AppColors.muted)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// Move queued items to the device trash. Returns true if it's safe to leave.
  Future<bool> _commitTrash() async {
    final toTrash =
        _assets.where((a) => _pendingTrash.contains(a.id)).toList();
    if (toTrash.isEmpty) return true;

    setState(() => _committing = true);

    // Snapshot each item's thumbnail + metadata *before* trashing — once
    // trashed, the asset can no longer be read back for the Trash page.
    final captures = <String, ({Uint8List? thumb, TrashRecord record})>{};
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final a in toTrash) {
      final thumb =
          await a.thumbnailDataWithSize(const ThumbnailSize(400, 400));
      final name = await a.titleAsync;
      captures[a.id] = (
        thumb: thumb,
        record: TrashRecord(
          id: a.id,
          name: name,
          dateMillis: a.createDateTime.millisecondsSinceEpoch,
          isVideo: a.type == AssetType.video,
          durationSeconds: a.videoDuration.inSeconds,
          trashedAtMillis: now,
        ),
      );
    }

    List<String> trashed = const [];
    try {
      trashed = await widget.service.moveToTrash(toTrash);
    } catch (e) {
      if (mounted) {
        setState(() => _committing = false);
        _toast('Couldn\'t move to Trash. Please try again.');
      }
      return false;
    }

    // Record trashed items for the Trash page, and drop them from Favorites.
    for (final id in trashed) {
      final cap = captures[id];
      if (cap != null) await trashService.add(cap.record, cap.thumb);
      if (favorites.isFavorite(id)) await favorites.toggle(id);
    }

    if (!mounted) return false;
    setState(() {
      _pendingTrash.removeAll(trashed);
      _committedTrashCount += trashed.length;
      _committing = false;
    });

    if (trashed.isEmpty) {
      _toast('Nothing was moved to Trash.');
      return false;
    }
    return true;
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: AppTheme.body(context, size: 14)),
        backgroundColor: AppColors.surfaceHigh,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _pendingTrash.isEmpty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  _topBar(),
                  Expanded(child: _buildDeck()),
                  if (!_loading && _assets.isNotEmpty) _footer(),
                ],
              ),
              if (_committing)
                const ColoredBox(
                  color: Color(0x99000000),
                  child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.mist),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar() {
    final total = _assets.length;
    final shown = _finished ? total : (total == 0 ? 0 : _topIndex + 1);
    final progress = total == 0 ? 0.0 : shown / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 6, 20, 6),
      child: Row(
        children: [
          IconButton(
            onPressed: _handleBack,
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.mist),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.album.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.display(context, size: 18),
                ),
                const SizedBox(height: 6),
                _ProgressBar(value: progress),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Text(
            total == 0 ? '0 / 0' : formatCounter(shown, total),
            style: AppTheme.mono(context, size: 13, color: AppColors.muted),
          ),
          IconButton(
            onPressed: _loading ? null : _pickSort,
            tooltip: 'Sort deck',
            icon: const Icon(Icons.sort_rounded, color: AppColors.mist),
          ),
        ],
      ),
    );
  }

  Widget _buildDeck() {
    if (_loading) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.muted),
      );
    }
    if (_assets.isEmpty) {
      return const EmptyView(
        icon: Icons.image_outlined,
        title: 'Nothing to sort',
        message: 'This album has no photos or videos.',
      );
    }
    if (_finished) {
      return _EndState(
        pendingCount: _pendingTrash.length,
        onBack: _handleBack,
      );
    }

    final displayed = _assets.length < 2 ? _assets.length : 2;

    return CardSwiper(
      key: ValueKey(_sort),
      controller: _controller,
      cardsCount: _assets.length,
      initialIndex: _startIndex,
      numberOfCardsDisplayed: displayed,
      isLoop: false,
      backCardOffset: const Offset(0, 32),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
      allowedSwipeDirection:
          const AllowedSwipeDirection.symmetric(horizontal: true),
      onSwipe: _onSwipe,
      onUndo: _onUndo,
      cardBuilder: (context, index, percentX, percentY) {
        final asset = _assets[index];
        return GestureDetector(
          key: ValueKey(asset.id),
          onTap: () => _openViewer(index),
          child: Stack(
            fit: StackFit.expand,
            children: [
              MediaCard(asset: asset, service: widget.service),
              // Only the top card reacts to the drag.
              if (index == _topIndex) SwipeOverlay(percentX: percentX / 100),
            ],
          ),
        );
      },
    );
  }

  Widget _footer() {
    final pending = _pendingTrash.length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        children: [
          _UndoButton(onPressed: _canUndo ? _controller.undo : null),
          const Spacer(),
          if (pending > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.rose.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(AppRadii.pill),
                border: Border.all(color: AppColors.rose.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.delete_outline_rounded,
                      size: 16, color: AppColors.rose),
                  const SizedBox(width: 6),
                  Text(
                    '$pending to delete',
                    style: AppTheme.mono(context, size: 13,
                        color: AppColors.rose),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

enum _ExitChoice { trash, keep, cancel }

class _UndoButton extends StatelessWidget {
  const _UndoButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? AppColors.mist : AppColors.muted;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        side: BorderSide(
            color: enabled ? AppColors.line : AppColors.line.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.pill)),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
      icon: Icon(Icons.undo_rounded, size: 18, color: color),
      label: Text('Undo',
          style: AppTheme.body(context, size: 14, weight: FontWeight.w600,
              color: color)),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value.clamp(0.0, 1.0),
        minHeight: 3,
        backgroundColor: AppColors.line,
        valueColor: const AlwaysStoppedAnimation(AppColors.teal),
      ),
    );
  }
}

class _EndState extends StatelessWidget {
  const _EndState({required this.pendingCount, required this.onBack});

  final int pendingCount;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 48, color: AppColors.teal),
          const SizedBox(height: 18),
          Text('All caught up', style: AppTheme.display(context, size: 22)),
          const SizedBox(height: 8),
          Text(
            pendingCount == 0
                ? "You've been through every item in this album."
                : "$pendingCount item${pendingCount == 1 ? '' : 's'} ready for "
                    "the Trash. You'll confirm on the way out.",
            textAlign: TextAlign.center,
            style: AppTheme.body(context, size: 14, color: AppColors.muted),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onBack,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.mist,
              foregroundColor: AppColors.ink,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
            child: Text(
              pendingCount == 0 ? 'Back to albums' : 'Review & finish',
              style: AppTheme.body(context,
                  size: 15, weight: FontWeight.w600, color: AppColors.ink),
            ),
          ),
        ],
      ),
    );
  }
}
