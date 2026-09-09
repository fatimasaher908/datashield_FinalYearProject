import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'storage_service.dart';

class EncryptedMediaInfo {
  final String name;
  final String uri;
  final int size;

  const EncryptedMediaInfo({
    required this.name,
    required this.uri,
    required this.size,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'uri': uri,
      'size': size,
    };
  }

  @override
  String toString() {
    return 'EncryptedMediaInfo('
        'name: $name, '
        'uri: $uri, '
        'size: $size'
        ')';
  }
}

class PhotoRetrievalService {
  // ============================================================
  // METHOD CHANNEL
  // ============================================================

  static const MethodChannel _channel =
      MethodChannel('datashield/media');

  // ============================================================
  // GET ENCRYPTED PHOTOS / VIDEOS
  // ============================================================

  /// Finds every encrypted media file inside:
  ///
  ///   Pictures/
  ///   DCIM/
  ///
  /// including all subfolders.
  ///
  /// IMPORTANT:
  /// This method ONLY retrieves encrypted files.
  /// It NEVER decrypts them.
  static Future<List<EncryptedMediaInfo>>
      getEncryptedPhotos() async {
    final List<EncryptedMediaInfo> encryptedFiles = [];

    try {
      // --------------------------------------------------------
      // Get saved media folder URIs
      // --------------------------------------------------------

      final mediaFolders =
          await StorageService.getMediaFolders();

      if (mediaFolders.isEmpty) {
        debugPrint(
          'PhotoRetrievalService: '
          'No protected media folders found.',
        );

        return encryptedFiles;
      }

      // --------------------------------------------------------
      // Search Pictures
      // --------------------------------------------------------

      final picturesUri =
          mediaFolders['picturesUri'];

      if (picturesUri != null &&
          picturesUri.isNotEmpty) {
        debugPrint(
          'PhotoRetrievalService: '
          'Scanning Pictures...',
        );

        final picturesFiles =
            await _findEncryptedFiles(
          picturesUri,
        );

        encryptedFiles.addAll(
          picturesFiles,
        );
      }

      // --------------------------------------------------------
      // Search DCIM
      // --------------------------------------------------------

      final dcimUri =
          mediaFolders['dcimUri'];

      if (dcimUri != null &&
          dcimUri.isNotEmpty) {
        debugPrint(
          'PhotoRetrievalService: '
          'Scanning DCIM...',
        );

        final dcimFiles =
            await _findEncryptedFiles(
          dcimUri,
        );

        encryptedFiles.addAll(
          dcimFiles,
        );
      }

      debugPrint(
        'PhotoRetrievalService: '
        'Found ${encryptedFiles.length} encrypted files.',
      );

      return encryptedFiles;
    } catch (e) {
      debugPrint(
        'PhotoRetrievalService error: $e',
      );

      return encryptedFiles;
    }
  }

  // ============================================================
  // RECURSIVE SEARCH
  // ============================================================

  /// Recursively searches a SAF directory for `.dsenc` files.
  ///
  /// The actual SAF traversal is performed by Android/Kotlin.
  static Future<List<EncryptedMediaInfo>>
      _findEncryptedFiles(
    String folderUri,
  ) async {
    try {
      final result =
          await _channel.invokeMethod<List<dynamic>>(
        'findEncryptedFiles',
        {
          'folderUri': folderUri,
        },
      );

      if (result == null) {
        return [];
      }

      final List<EncryptedMediaInfo> files = [];

      for (final item in result) {
        if (item is! Map) {
          continue;
        }

        final name =
            item['name']?.toString();

        final uri =
            item['uri']?.toString();

        final sizeValue =
            item['size'];

        if (name == null ||
            name.isEmpty ||
            uri == null ||
            uri.isEmpty) {
          continue;
        }

        int size = 0;

        if (sizeValue is int) {
          size = sizeValue;
        } else if (sizeValue != null) {
          size =
              int.tryParse(
                    sizeValue.toString(),
                  ) ??
                  0;
        }

        files.add(
          EncryptedMediaInfo(
            name: name,
            uri: uri,
            size: size,
          ),
        );
      }

      return files;
    } on PlatformException catch (e) {
      debugPrint(
        'Failed to find encrypted files: '
        '${e.code} - ${e.message}',
      );

      return [];
    } catch (e) {
      debugPrint(
        'Encrypted file search error: $e',
      );

      return [];
    }
  }

  // ============================================================
  // GET ONE ENCRYPTED FILE
  // ============================================================

  /// Retrieves the raw encrypted bytes of ONE `.dsenc` file.
  ///
  /// IMPORTANT:
  /// These bytes are still encrypted.
  ///
  /// This method is intended for testing and smaller files.
  /// For large videos, use the streaming method that we will
  /// connect to the HTTP/TLS tunnel.
  static Future<Uint8List?> getEncryptedBytes(
    String uri,
  ) async {
    try {
      final result =
          await _channel.invokeMethod<Uint8List>(
        'readEncryptedFile',
        {
          'uri': uri,
        },
      );

      if (result == null) {
        debugPrint(
          'No encrypted bytes returned for: $uri',
        );

        return null;
      }

      debugPrint(
        'Read ${result.length} encrypted bytes.',
      );

      return result;
    } on PlatformException catch (e) {
      debugPrint(
        'Failed to read encrypted file: '
        '${e.code} - ${e.message}',
      );

      return null;
    } catch (e) {
      debugPrint(
        'Encrypted file read error: $e',
      );

      return null;
    }
  }
}