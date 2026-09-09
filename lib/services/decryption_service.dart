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