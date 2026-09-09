import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../services/decryption_service.dart';

class VideoViewerScreen extends StatefulWidget {
  final String encryptedUri;
  final String fileName;
  final Uint8List encryptionKey;

  const VideoViewerScreen({
    super.key,
    required this.encryptedUri,
    required this.fileName,
    required this.encryptionKey,
  });

  @override
  State<VideoViewerScreen> createState() => _VideoViewerScreenState();
}

class _VideoViewerScreenState
    extends State<VideoViewerScreen> {
  VideoPlayerController? _controller;

  String? _tempFilePath;

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _decryptAndLoadVideo();
  }

  Future<void> _decryptAndLoadVideo() async {
    try {
      final path =
          await DecryptionService.decryptToTempFile(
        widget.encryptedUri,
        widget.fileName,
        widget.encryptionKey,
      );

      if (path == null || path.isEmpty) {
        throw Exception(
          "Could not decrypt video.",
        );
      }

      _tempFilePath = path;

      final controller =
          VideoPlayerController.file(
        File(path),
      );

      await controller.initialize();

      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _controller = controller;
        _loading = false;
      });

      await controller.play();
    } catch (e) {
      print("Video loading error: $e");

      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();

    _deleteTemporaryFile();

    super.dispose();
  }

  Future<void> _deleteTemporaryFile() async {
    final path = _tempFilePath;

    if (path == null || path.isEmpty) {
      return;
    }

    try {
      final file = File(path);

      if (await file.exists()) {
        await file.delete();

        print(
          "Temporary decrypted video deleted.",
        );
      }
    } catch (e) {
      print(
        "Failed to delete temporary video: $e",
      );
    }
  }

  String _formatDuration(Duration duration) {
    final minutes =
        duration.inMinutes.remainder(60)
            .toString()
            .padLeft(2, '0');

    final seconds =
        duration.inSeconds.remainder(60)
            .toString()
            .padLeft(2, '0');

    if (duration.inHours > 0) {
      final hours =
          duration.inHours
              .toString()
              .padLeft(2, '0');

      return "$hours:$minutes:$seconds";
    }

    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.fileName,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: Center(
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: Colors.white,
          ),
          SizedBox(height: 20),
          Text(
            "Decrypting video...",
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
          ),
        ],
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 60,
            ),
            const SizedBox(height: 16),
            const Text(
              "Unable to play video",
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white70,
              ),
            ),
          ],
        ),
      );
    }

    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return const Text(
        "Video could not be loaded.",
        style: TextStyle(color: Colors.white),
      );
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),

        const SizedBox(height: 20),

        ValueListenableBuilder(
          valueListenable: controller,
          builder: (
            context,
            VideoPlayerValue value,
            child,
          ) {
            return Column(
              children: [
                Slider(
                  value: value.position.inMilliseconds
                      .clamp(
                        0,
                        value.duration.inMilliseconds,
                      )
                      .toDouble(),
                  min: 0,
                  max: value.duration.inMilliseconds
                      .toDouble()
                      .clamp(1, double.infinity),
                  onChanged: (newValue) {
                    controller.seekTo(
                      Duration(
                        milliseconds:
                            newValue.toInt(),
                      ),
                    );
                  },
                ),

                Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 20,
                  ),
                  child: Row(
                    mainAxisAlignment:
                        MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _formatDuration(
                          value.position,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        _formatDuration(
                          value.duration,
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),

                IconButton(
                  iconSize: 56,
                  color: Colors.white,
                  icon: Icon(
                    value.isPlaying
                        ? Icons.pause_circle
                        : Icons.play_circle,
                  ),
                  onPressed: () {
                    if (value.isPlaying) {
                      controller.pause();
                    } else {
                      controller.play();
                    }
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}