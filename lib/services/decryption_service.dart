import 'dart:io';
import 'dart:typed_data';


import 'package:flutter/services.dart';

class DecryptionService {
  static const MethodChannel _channel =
      MethodChannel("datashield/encryption");

  // ============================================================
  // GET ENCRYPTED MEDIA FROM BOTH PICTURES + DCIM
  // ============================================================

  static Future<List<dynamic>> getEncryptedMedia({
    required String? picturesUri,
    required String? dcimUri,
  }) async {
    try {
      final List<dynamic> media =
          await _channel.invokeMethod(
        "getEncryptedMedia",
        {
          "picturesUri": picturesUri,
          "dcimUri": dcimUri,
        },
      );

      return media;
    } catch (e) {
      print("Error getting encrypted media: $e");
      return [];
    }
  }

  // ============================================================
  // OLD METHOD - KEPT FOR COMPATIBILITY
  // ============================================================

  static Future<List<dynamic>> getEncryptedImages(
    String folderUri,
  ) async {
    try {
      final List<dynamic> images =
          await _channel.invokeMethod(
        "getEncryptedImages",
        {
          "uri": folderUri,
        },
      );

      return images;
    } catch (e) {
      print("Error getting encrypted images: $e");
      return [];
    }
  }

  // ============================================================
  // DECRYPT IMAGE
  // ============================================================

  static Future<Uint8List?> decryptImage(
    String imageUri,
    Uint8List key,
  ) async {
    try {
      final result = await _channel.invokeMethod(
        "decryptImage",
        {
          "uri": imageUri,
          "key": key,
        },
      );

      if (result == null) {
        print("Decryption returned NULL");
        return null;
      }

      final Uint8List bytes =
          result is Uint8List
              ? result
              : Uint8List.fromList(
                  List<int>.from(result),
                );

      print(
        "Flutter received decrypted bytes: ${bytes.length}",
      );

      return bytes;
    } catch (e) {
      print("Decryption error: $e");
      return null;
    }
  }

  // ============================================================
  // DECRYPT VIDEO / MEDIA TO TEMPORARY FILE
  //
  // Used when the user actually opens a video.
  //
  // This remains unchanged so your currently working
  // video playback continues to work.
  // ============================================================

  static Future<String?> decryptToTempFile(
    String encryptedUri,
    String fileName,
    Uint8List key,
  ) async {
    try {
      final result = await _channel.invokeMethod(
        "decryptToTempFile",
        {
          "uri": encryptedUri,
          "name": fileName,
          "key": key,
        },
      );

      if (result == null) {
        print("Video decryption returned NULL");
        return null;
      }

      final String path = result.toString();

      print("Video decrypted to temporary file:");
      print(path);

      return path;
    } catch (e) {
      print("Video decryption error: $e");
      return null;
    }
  }

// ============================================================
// GENERATE VIDEO THUMBNAIL + RETAIN DECRYPTED VIDEO
//
// IMPORTANT:
//
// Android decrypts the video ONLY ONCE.
//
// The native side returns:
//   thumbnailBytes -> JPEG thumbnail
//   videoPath      -> decrypted temporary MP4
//
// GalleryScreen will keep both values.
//
// The videoPath will later be passed directly to
// VideoViewerScreen so the video does NOT need to be
// decrypted a second time.
// ============================================================

static Future<Map<String, dynamic>?> generateVideoThumbnail(
  String encryptedUri,
  String fileName,
  Uint8List key,
) async {
  try {
    final result = await _channel.invokeMethod(
      "generateVideoThumbnail",
      {
        "uri": encryptedUri,
        "name": fileName,
        "key": key,
      },
    );

    if (result == null) {
      print("Video thumbnail generation returned NULL");
      return null;
    }

    // ----------------------------------------------------------
    // METHOD CHANNEL RETURNS A MAP
    // ----------------------------------------------------------

    if (result is! Map) {
      print(
        "Video thumbnail generation returned invalid data: "
        "${result.runtimeType}",
      );

      return null;
    }

    // ----------------------------------------------------------
    // GET THUMBNAIL BYTES
    // ----------------------------------------------------------

    final rawThumbnailBytes =
        result["thumbnailBytes"];

    if (rawThumbnailBytes == null) {
      print("Video thumbnail bytes are missing");
      return null;
    }

    final Uint8List thumbnailBytes =
        rawThumbnailBytes is Uint8List
            ? rawThumbnailBytes
            : Uint8List.fromList(
                List<int>.from(rawThumbnailBytes),
              );

    // ----------------------------------------------------------
    // GET DECRYPTED VIDEO PATH
    // ----------------------------------------------------------

    final rawVideoPath =
        result["videoPath"];

    if (rawVideoPath == null) {
      print("Decrypted video path is missing");
      return null;
    }

    final String videoPath =
        rawVideoPath.toString();

    if (videoPath.isEmpty) {
      print("Decrypted video path is empty");
      return null;
    }

    // ----------------------------------------------------------
    // LOG SUCCESS
    // ----------------------------------------------------------

    print(
      "Flutter received video thumbnail bytes: "
      "${thumbnailBytes.length}",
    );

    print(
      "Flutter received retained decrypted video path:",
    );

    print(videoPath);

    // ----------------------------------------------------------
    // RETURN BOTH VALUES
    // ----------------------------------------------------------

    return {
      "thumbnailBytes": thumbnailBytes,
      "videoPath": videoPath,
    };
  } catch (e) {
    print(
      "Video thumbnail generation error: $e",
    );

    return null;
  }
}

  // ============================================================
  // DELETE RETAINED DECRYPTED VIDEO
  //
  // Deletes a temporary decrypted MP4 created by
  // generateVideoThumbnail().
  //
  // This is safe because GalleryScreen owns these files.
  // ============================================================

  static Future<bool> deleteTemporaryVideo(
    String videoPath,
  ) async {
    try {
      if (videoPath.isEmpty) {
        return false;
      }

      final file = File(videoPath);

      if (!await file.exists()) {
        print(
          "Temporary video already missing:",
        );
        print(videoPath);

        return false;
      }

      await file.delete();

      print(
        "Temporary decrypted video deleted:",
      );
      print(videoPath);

      return true;
    } catch (e) {
      print(
        "Error deleting temporary decrypted video: $e",
      );

      return false;
    }
  }

  // ============================================================
  // DELETE ENCRYPTED MEDIA
  // ============================================================

  static Future<void> deleteEncryptedImage(
    String imageUri,
  ) async {
    try {
      await _channel.invokeMethod(
        "deleteEncryptedImage",
        {
          "uri": imageUri,
        },
      );
    } catch (e) {
      print("Error deleting encrypted media: $e");
    }
  }
}