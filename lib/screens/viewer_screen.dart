import 'dart:io';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_view/photo_view.dart';
import 'package:video_player/video_player.dart';

import '../services/gallery_service.dart';
import '../theme/app_theme.dart';
import '../utils/formatters.dart';
import '../widgets/favorite_button.dart';
import '../widgets/spec_strip.dart';

/// Fullscreen viewer: pinch-zoom for images, playback for videos. Tapping the
/// media toggles a metadata overlay (filename + spec strip).
class ViewerScreen extends StatefulWidget {
  const ViewerScreen({
    super.key,
    required this.asset,
    required this.service,
  });

  final AssetEntity asset;
  final GalleryService service;

  @override
  State<ViewerScreen> createState() => _ViewerScreenState();
}

class _ViewerScreenState extends State<ViewerScreen> {
  File? _file;
  int? _sizeBytes;
  String? _title;
  VideoPlayerController? _video;
  bool _showChrome = true;
  bool _error = false;

  bool get _isVideo => widget.asset.type == AssetType.video;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _video?.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final asset = widget.asset;
    final title = await asset.titleAsync;
    final file = await asset.file;
    final size = await widget.service.fileSize(asset);
    if (!mounted) return;

    if (file == null) {
      setState(() {
        _error = true;
        _title = title;
        _sizeBytes = size;
      });
      return;
    }

    if (_isVideo) {
      final controller = VideoPlayerController.file(file);
      try {
        await controller.initialize();
      } catch (_) {
        controller.dispose();
        if (!mounted) return;
        setState(() {
          _error = true;
          _title = title;
          _sizeBytes = size;
        });
        return;
      }
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() {
        _file = file;
        _title = title;
        _sizeBytes = size;
        _video = controller;
      });
      await controller.play();
    } else {
      setState(() {
        _file = file;
        _title = title;
        _sizeBytes = size;
      });
    }
  }

  void _toggleChrome() => setState(() => _showChrome = !_showChrome);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          Positioned.fill(child: _buildMedia()),
          _buildChrome(),
        ],
      ),
    );
  }

  Widget _buildMedia() {
    if (_error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.broken_image_outlined,
                color: AppColors.muted, size: 40),
            const SizedBox(height: 12),
            Text("This file couldn't be opened.",
                style: AppTheme.body(context, size: 14, color: AppColors.muted)),
          ],
        ),
      );
    }
    if (_file == null) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.muted),
      );
    }
    if (_isVideo) {
      return _VideoView(controller: _video!, onTap: _toggleChrome);
    }
    return PhotoView(
      imageProvider: FileImage(_file!),
      backgroundDecoration: const BoxDecoration(color: Colors.black),
      minScale: PhotoViewComputedScale.contained,
      maxScale: PhotoViewComputedScale.covered * 3,
      initialScale: PhotoViewComputedScale.contained,
      onTapUp: (_, _, _) => _toggleChrome(),
      loadingBuilder: (_, _) => const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.muted),
      ),
    );
  }

  Widget _buildChrome() {
    return AnimatedOpacity(
      opacity: _showChrome ? 1 : 0,
      duration: const Duration(milliseconds: 180),
      child: IgnorePointer(
        ignoring: !_showChrome,
        child: Column(
          children: [
            _topBar(),
            const Spacer(),
            if (_isVideo && _video != null && _video!.value.isInitialized)
              _VideoControls(controller: _video!),
            _bottomMeta(),
          ],
        ),
      ),
    );
  }

  Widget _topBar() {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        left: 4,
        right: 16,
        bottom: 12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xB3000000), Color(0x00000000)],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded, color: AppColors.mist),
          ),
          Expanded(
            child: Text(
              _title ?? '',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.mono(context, size: 13, color: AppColors.mist),
            ),
          ),
          FavoriteButton(assetId: widget.asset.id, size: 24, onSurface: true),
        ],
      ),
    );
  }

  Widget _bottomMeta() {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Color(0xB3000000), Color(0x00000000)],
        ),
      ),
      child: SpecStrip(
        sizeBytes: _sizeBytes,
        date: widget.asset.createDateTime,
        isVideo: _isVideo,
        duration: _isVideo ? widget.asset.videoDuration : null,
        dimensions: Size(
          widget.asset.width.toDouble(),
          widget.asset.height.toDouble(),
        ),
      ),
    );
  }
}

/// Renders the video frame, centered and aspect-correct, with a tap target.
class _VideoView extends StatelessWidget {
  const _VideoView({required this.controller, required this.onTap});

  final VideoPlayerController controller;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ColoredBox(
        color: Colors.black,
        child: Center(
          child: AspectRatio(
            aspectRatio: controller.value.aspectRatio == 0
                ? 16 / 9
                : controller.value.aspectRatio,
            child: VideoPlayer(controller),
          ),
        ),
      ),
    );
  }
}

/// Play/pause + scrub bar with mono timecodes.
class _VideoControls extends StatelessWidget {
  const _VideoControls({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<VideoPlayerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        final position = value.position;
        final total = value.duration;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: [
              IconButton(
                onPressed: () {
                  value.isPlaying ? controller.pause() : controller.play();
                },
                icon: Icon(
                  value.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: AppColors.mist,
                  size: 30,
                ),
              ),
              Text(
                formatDuration(position),
                style: AppTheme.mono(context, size: 12, color: AppColors.mist),
              ),
              Expanded(
                child: SliderTheme(
                  data: SliderThemeData(
                    trackHeight: 2,
                    activeTrackColor: AppColors.teal,
                    inactiveTrackColor: AppColors.line,
                    thumbColor: AppColors.mist,
                    overlayShape:
                        const RoundSliderOverlayShape(overlayRadius: 14),
                    thumbShape:
                        const RoundSliderThumbShape(enabledThumbRadius: 6),
                  ),
                  child: Slider(
                    value: _clampPos(position, total),
                    max: total.inMilliseconds.toDouble().clamp(1, double.infinity),
                    onChanged: (v) {
                      controller.seekTo(Duration(milliseconds: v.round()));
                    },
                  ),
                ),
              ),
              Text(
                formatDuration(total),
                style: AppTheme.mono(context, size: 12, color: AppColors.muted),
              ),
            ],
          ),
        );
      },
    );
  }

  double _clampPos(Duration position, Duration total) {
    final pos = position.inMilliseconds.toDouble();
    final max = total.inMilliseconds.toDouble();
    if (max <= 0) return 0;
    return pos.clamp(0, max);
  }
}
