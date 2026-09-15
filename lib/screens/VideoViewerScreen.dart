import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../services/decryption_service.dart';

class VideoViewerScreen extends StatefulWidget {
  final String encryptedUri;
  final String fileName;
  final Uint8List encryptionKey;

  // ============================================================
  // ALREADY DECRYPTED VIDEO
  //
  // When the gallery has already decrypted the video to create
  // its thumbnail, it can pass that same temporary file here.
  //
  // This prevents the video from being decrypted a second time.
  // ============================================================

  final String? tempVideoPath;

  const VideoViewerScreen({
    super.key,
    required this.encryptedUri,
    required this.fileName,
    required this.encryptionKey,
    this.tempVideoPath,
  });

  @override
  State<VideoViewerScreen> createState() =>
      _VideoViewerScreenState();
}

class _VideoViewerScreenState
    extends State<VideoViewerScreen> {

  String? _tempFilePath;

  bool _loading = true;
  String? _error;

  // ============================================================
  // WHETHER THIS SCREEN OWNS THE TEMP FILE
  //
  // If the gallery created the file, the gallery owns it.
  // Therefore this screen must NOT delete it.
  //
  // If this screen decrypts the file itself as a fallback,
  // this screen owns it and can delete it on dispose.
  // ============================================================

  bool _ownsTemporaryFile = false;

  @override
  void initState() {
    super.initState();

    _loadVideo();
  }

  // ============================================================
  // LOAD VIDEO
  //
  // 1. If gallery already decrypted the video:
  //      use that file immediately.
  //
  // 2. Otherwise:
  //      use the old decryption flow.
  //
  // This means videos opened from the gallery are NOT decrypted
  // again.
  // ============================================================

  Future<void> _loadVideo() async {
    try {

      // ========================================================
      // CASE 1:
      // GALLERY ALREADY DECRYPTED THE VIDEO
      // ========================================================

      if (widget.tempVideoPath != null &&
          widget.tempVideoPath!.isNotEmpty) {

        final path = widget.tempVideoPath!;

        print(
          "VIDEO VIEWER: Using existing decrypted video.",
        );

        print(
          "TEMP VIDEO PATH: $path",
        );

        final file = File(path);

        final exists = await file.exists();

        print(
          "TEMP VIDEO EXISTS: $exists",
        );

        if (!exists) {
          throw Exception(
            "The previously decrypted video file no longer exists.",
          );
        }

        final size = await file.length();

        print(
          "TEMP VIDEO SIZE: $size",
        );

        if (size <= 0) {
          throw Exception(
            "The previously decrypted video file is empty.",
          );
        }

        _tempFilePath = path;

        // ======================================================
        // IMPORTANT:
        // The gallery owns this file.
        //
        // Do NOT delete it from dispose().
        // ======================================================

        _ownsTemporaryFile = false;

        if (!mounted) {
          return;
        }

        setState(() {
          _loading = false;
        });

        return;
      }

      // ========================================================
      // CASE 2:
      // NO EXISTING TEMP FILE
      //
      // Keep the old working behavior as fallback.
      // ========================================================

      print(
        "VIDEO VIEWER: No existing decrypted video.",
      );

      print(
        "VIDEO VIEWER: Decrypting video...",
      );

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

      // This screen created the file, so it owns it.
      _ownsTemporaryFile = true;

      final file = File(path);

      final exists = await file.exists();

      print(
        "TEMP VIDEO EXISTS: $exists",
      );

      if (exists) {
        print(
          "TEMP VIDEO SIZE: ${await file.length()}",
        );
      }

      print(
        "TEMP VIDEO PATH: $path",
      );

      if (!exists) {
        throw Exception(
          "Temporary video file does not exist.",
        );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
      });

    } catch (e) {

      print(
        "Video loading error: $e",
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {

    // ==========================================================
    // ONLY DELETE THE TEMP FILE IF THIS SCREEN CREATED IT.
    //
    // If the gallery created it, the gallery continues to own
    // that file and can reuse it when the user returns.
    // ==========================================================

    if (_ownsTemporaryFile) {
      _deleteTemporaryFile();
    } else {
      print(
        "VIDEO VIEWER: Keeping gallery-owned temporary video.",
      );
    }

    super.dispose();
  }

  // ============================================================
  // DELETE TEMPORARY VIDEO
  // ============================================================

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

  // ============================================================
  // BUILD
  // ============================================================

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

      body: _buildBody(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {

    if (_loading) {

      return const Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [

            CircularProgressIndicator(
              color: Colors.white,
            ),

            SizedBox(height: 20),

            Text(
              "Loading video...",
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    if (_error != null) {

      return Center(
        child: Padding(
          padding:
              const EdgeInsets.all(24),

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
                  fontWeight:
                      FontWeight.bold,
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
        ),
      );
    }

    final path = _tempFilePath;

    if (path == null || path.isEmpty) {

      return const Center(
        child: Text(
          "Video could not be loaded.",
          style: TextStyle(
            color: Colors.white,
          ),
        ),
      );
    }

    // ==========================================================
    // EXISTING NATIVE VIDEO PLAYER
    //
    // No change to your working PlatformView.
    // It receives the already-decrypted MP4 path.
    // ==========================================================

    return AndroidView(
      viewType: "datashield/video_player",

      creationParams: path,

      creationParamsCodec:
          const StandardMessageCodec(),
    );
  }
}