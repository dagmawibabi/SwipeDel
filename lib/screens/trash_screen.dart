import 'dart:io';

import 'package:flutter/material.dart';

import '../services/trash_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/empty_view.dart';

/// Shows items swipedel has moved to the device trash, with permanent delete.
///
/// Restoring is done from the phone's own "Recently deleted" — Android offers
/// no programmatic un-trash — so this page focuses on clearing them for good.
class TrashScreen extends StatefulWidget {
  const TrashScreen({super.key});

  @override
  State<TrashScreen> createState() => _TrashScreenState();
}

class _TrashScreenState extends State<TrashScreen> {
  bool _busy = false;

  Future<void> _deleteForever(List<String> ids, {required bool all}) async {
    if (ids.isEmpty) return;
    final confirmed = await _confirm(count: ids.length, all: all);
    if (confirmed != true) return;

    setState(() => _busy = true);
    List<String> deleted = const [];
    try {
      deleted = await trashService.permanentlyDelete(ids);
    } catch (_) {
      // fall through to the toast below
    }
    if (!mounted) return;
    setState(() => _busy = false);

    if (deleted.isEmpty) {
      _toast('Nothing was deleted.');
    } else {
      _toast('Deleted ${deleted.length} item${deleted.length == 1 ? '' : 's'} '
          'for good.');
    }
  }

  Future<void> _restore(List<String> ids) async {
    if (ids.isEmpty) return;
    setState(() => _busy = true);
    List<String> restored = const [];
    try {
      restored = await trashService.restore(ids);
    } catch (_) {}
    if (!mounted) return;
    setState(() => _busy = false);
    _toast(restored.isEmpty
        ? 'Nothing was restored.'
        : 'Restored ${restored.length} item${restored.length == 1 ? '' : 's'}.');
  }

  Future<bool?> _confirm({required int count, required bool all}) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: AppColors.line),
        ),
        title: Text(
          all ? 'Empty the Trash?' : 'Delete forever?',
          style: AppTheme.display(context, size: 20),
        ),
        content: Text(
          all
              ? 'Permanently delete all $count item${count == 1 ? '' : 's'}. '
                  'This can\'t be undone.'
              : 'This item will be permanently deleted. This can\'t be undone.',
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
              backgroundColor: AppColors.rose,
              foregroundColor: Colors.white,
            ),
            child: Text(all ? 'Empty Trash' : 'Delete',
                style: AppTheme.body(context,
                    size: 14, weight: FontWeight.w600, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _itemSheet(TrashRecord record) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              title: Text(record.name.isEmpty ? 'Untitled' : record.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.body(context, size: 15)),
              subtitle: Text(
                '${record.isVideo ? 'Video' : 'Photo'} · ${formatDate(record.date)}',
                style: AppTheme.mono(context, size: 12, color: AppColors.muted),
              ),
            ),
            const Divider(color: AppColors.line, height: 1),
            ListTile(
              leading:
                  const Icon(Icons.restore_rounded, color: AppColors.teal),
              title: Text('Restore',
                  style: AppTheme.body(context, size: 15)),
              subtitle: Text('Put it back in your gallery',
                  style:
                      AppTheme.body(context, size: 12, color: AppColors.muted)),
              onTap: () {
                Navigator.of(context).pop();
                _restore([record.id]);
              },
            ),
            ListTile(
              leading:
                  const Icon(Icons.delete_forever_rounded, color: AppColors.rose),
              title: Text('Delete forever',
                  style: AppTheme.body(context, size: 15, color: AppColors.rose)),
              onTap: () {
                Navigator.of(context).pop();
                _deleteForever([record.id], all: false);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
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
    return AnimatedBuilder(
      animation: trashService,
      builder: (context, _) {
        final records = trashService.records;
        return Scaffold(
          appBar: AppBar(
            title: Text('Trash', style: AppTheme.display(context, size: 20)),
            actions: [
              if (records.isNotEmpty)
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => _deleteForever(
                            records.map((r) => r.id).toList(),
                            all: true,
                          ),
                  child: Text('Empty',
                      style: AppTheme.body(context,
                          size: 14, weight: FontWeight.w600,
                          color: AppColors.rose)),
                ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Stack(
              children: [
                if (records.isEmpty)
                  const EmptyView(
                    icon: Icons.delete_outline_rounded,
                    title: 'Trash is empty',
                    message: 'Items you swipe left land here on your way out of '
                        'an album.',
                  )
                else
                  _grid(records),
                if (_busy)
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
        );
      },
    );
  }

  Widget _grid(List<TrashRecord> records) {
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _banner()),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _TrashTile(
                key: ValueKey(records[i].id),
                record: records[i],
                onTap: () => _itemSheet(records[i]),
              ),
              childCount: records.length,
            ),
          ),
        ),
      ],
    );
  }

  Widget _banner() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded,
                size: 18, color: AppColors.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Tap an item to restore it to your gallery or delete it for '
                'good.',
                style: AppTheme.body(context, size: 13, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrashTile extends StatelessWidget {
  const _TrashTile({super.key, required this.record, required this.onTap});

  final TrashRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final thumb = File(trashService.thumbPath(record.id));
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: AppColors.surface,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (thumb.existsSync())
                Image.file(thumb, fit: BoxFit.cover, gaplessPlayback: true)
              else
                const Center(
                  child: Icon(Icons.image_not_supported_outlined,
                      color: AppColors.muted, size: 20),
                ),
              if (record.isVideo)
                const Positioned(
                  left: 6,
                  bottom: 6,
                  child: Icon(Icons.play_circle_fill_rounded,
                      color: AppColors.mist, size: 20),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
