import 'package:dynamic_photo_chat_flutter/utils/media_downloader.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

class DynamicPhotoScreen extends StatefulWidget {
  const DynamicPhotoScreen({
    super.key,
    required this.coverUrl,
    required this.videoUrl,
    this.title,
  });

  final String coverUrl;
  final String videoUrl;
  final String? title;

  @override
  State<DynamicPhotoScreen> createState() => _DynamicPhotoScreenState();
}

class _DynamicPhotoScreenState extends State<DynamicPhotoScreen> {
  VideoPlayerController? _controller;
  bool _loading = false;
  bool _holding = false;
  bool _showVideo = false;
  double _aspectRatio = 3 / 4;
  int _received = 0;
  int? _total;
  String? _error;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _ensureController() async {
    if (_controller != null) return;
    setState(() {
      _loading = true;
      _error = null;
      _received = 0;
      _total = null;
    });

    try {
      final downloaded = await MediaDownloader.downloadToCacheFile(
        url: widget.videoUrl,
        extensionHint: 'mp4',
        onProgress: (received, total) {
          if (!mounted) return;
          setState(() {
            _received = received;
            _total = total;
          });
        },
      );
      final controller = VideoPlayerController.file(downloaded.file);
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      final ratio = controller.value.aspectRatio;
      if (ratio.isFinite && ratio > 0) {
        _aspectRatio = ratio;
      }
      _controller = controller;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _startPreview() async {
    _holding = true;
    await HapticFeedback.selectionClick();
    await _ensureController();
    final controller = _controller;
    if (!_holding || controller == null) return;
    await controller.seekTo(Duration.zero);
    await controller.play();
    if (mounted) {
      setState(() => _showVideo = true);
    }
  }

  Future<void> _stopPreview() async {
    _holding = false;
    final controller = _controller;
    if (controller != null) {
      await controller.pause();
      await controller.seekTo(Duration.zero);
    }
    if (mounted) {
      setState(() => _showVideo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final progress = (_total == null || _total == 0)
        ? null
        : (_received / _total!).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF4F6F8),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(widget.title ?? 'Live Photo'),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: GestureDetector(
                      onLongPressStart: (_) => _startPreview(),
                      onLongPressEnd: (_) => _stopPreview(),
                      onLongPressUp: _stopPreview,
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 180),
                        scale: _holding ? 0.985 : 1.0,
                        curve: Curves.easeOutCubic,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: AspectRatio(
                            aspectRatio: _aspectRatio,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                Container(color: const Color(0xFFE5E7EB)),
                                if (widget.coverUrl.trim().isNotEmpty)
                                  Image.network(
                                    widget.coverUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) =>
                                        const _DetailPlaceholder(),
                                  )
                                else
                                  const _DetailPlaceholder(),
                                if (_showVideo &&
                                    controller != null &&
                                    controller.value.isInitialized)
                                  FittedBox(
                                    fit: BoxFit.contain,
                                    child: SizedBox(
                                      width: controller.value.size.width,
                                      height: controller.value.size.height,
                                      child: VideoPlayer(controller),
                                    ),
                                  ),
                                Positioned(
                                  top: 16,
                                  left: 16,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.45),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 4,
                                          backgroundColor: Color(0xFFFF4D4F),
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'LIVE',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                if (_loading)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withOpacity(0.18),
                                      alignment: Alignment.center,
                                      child: SizedBox(
                                        width: 220,
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            LinearProgressIndicator(
                                              value: progress,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              progress == null
                                                  ? 'Loading motion...'
                                                  : 'Loading motion... ${(progress * 100).round()}%',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                if (_error != null)
                                  Positioned.fill(
                                    child: Container(
                                      color: Colors.black.withOpacity(0.28),
                                      alignment: Alignment.center,
                                      padding: const EdgeInsets.all(24),
                                      child: Text(
                                        _error!,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: const Text(
                    'Press and hold to preview the motion, similar to Live Photo on iPhone. Release to return to the cover image.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF475569),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailPlaceholder extends StatelessWidget {
  const _DetailPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF1F5F9),
      alignment: Alignment.center,
      child: const Icon(
        Icons.photo_outlined,
        size: 40,
        color: Color(0xFF94A3B8),
      ),
    );
  }
}
