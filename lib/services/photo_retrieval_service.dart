import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import 'storage_service.dart';


// ============================================================
// ENCRYPTED MEDIA INFORMATION
// ============================================================

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


// ============================================================
// PHOTO RETRIEVAL SERVICE
// ============================================================

class PhotoRetrievalService {

  // ============================================================
  // METHOD CHANNEL
  // ============================================================

  static const MethodChannel _channel =
      MethodChannel('datashield/media');


  // ============================================================
  // SHA-256 DEBUG HELPER
  // ============================================================
  //
  // This calculates SHA-256 of the exact encrypted bytes.
  //
  // IMPORTANT:
  // This is ONLY for debugging.
  // It does not modify the encrypted data.
  // ============================================================

  static Future<String> _sha256Hex(
    Uint8List bytes,
  ) async {

    try {

      final result =
          await _channel.invokeMethod<String>(
        'sha256Bytes',
        {
          'bytes': bytes,
        },
      );

      if (result != null &&
          result.isNotEmpty) {

        return result;
      }

    } catch (e) {

      debugPrint(
        'HASH DEBUG: Native SHA-256 unavailable: $e',
      );
    }

    return 'HASH_NOT_AVAILABLE';
  }


  // ============================================================
  // DEBUG BYTE → HEX
  // ============================================================

  static String _bytesToHex(
    Uint8List bytes, {
    int maxBytes = 32,
  }) {

    final end =
        bytes.length < maxBytes
            ? bytes.length
            : maxBytes;

    return bytes
        .sublist(0, end)
        .map(
          (byte) => byte
              .toRadixString(16)
              .padLeft(2, '0')
              .toUpperCase(),
        )
        .join(' ');
  }


  // ============================================================
  // DEBUG LAST BYTES → HEX
  // ============================================================

  static String _lastBytesToHex(
    Uint8List bytes, {
    int count = 16,
  }) {

    if (bytes.isEmpty) {
      return '';
    }

    final start =
        bytes.length > count
            ? bytes.length - count
            : 0;

    return bytes
        .sublist(start)
        .map(
          (byte) => byte
              .toRadixString(16)
              .padLeft(2, '0')
              .toUpperCase(),
        )
        .join(' ');
  }


  // ============================================================
  // FULL ENCRYPTED FILE DEBUG
  // ============================================================
  //
  // Logs:
  //
  // 1. File size
  // 2. SHA-256
  // 3. First 32 bytes
  // 4. Last 16 bytes
  //
  // This allows us to compare:
  //
  // Android
  //     ↓
  // Node
  //     ↓
  // Browser
  //
  // and determine whether the encrypted bytes changed.
  // ============================================================

  static Future<void> _debugEncryptedBytes(
    String label,
    Uint8List bytes,
  ) async {

    debugPrint('');
    debugPrint(
      '============================================================',
    );

    debugPrint(
      'HASH DEBUG: $label',
    );

    debugPrint(
      '============================================================',
    );

    debugPrint(
      'HASH DEBUG: Size = ${bytes.length} bytes',
    );

    // ----------------------------------------------------------
    // First 32 bytes
    // ----------------------------------------------------------

    debugPrint(
      'HASH DEBUG: FIRST 32 BYTES = '
      '${_bytesToHex(bytes, maxBytes: 32)}',
    );

    // ----------------------------------------------------------
    // Last 16 bytes
    // ----------------------------------------------------------

    debugPrint(
      'HASH DEBUG: LAST 16 BYTES = '
      '${_lastBytesToHex(bytes, count: 16)}',
    );

    // ----------------------------------------------------------
    // SHA-256
    // ----------------------------------------------------------

    final hash =
        await _sha256Hex(bytes);

    debugPrint(
      'HASH DEBUG: SHA-256 = $hash',
    );

    debugPrint(
      '============================================================',
    );
  }


  // ============================================================
  // GET ENCRYPTED PHOTOS / VIDEOS
  // ============================================================

  /// Finds every encrypted media file inside:
  ///
  ///     Pictures/
  ///     DCIM/
  ///
  /// including subfolders.
  ///
  /// IMPORTANT:
  /// This method ONLY finds encrypted files.
  /// It does NOT decrypt anything.
  static Future<List<EncryptedMediaInfo>>
      getEncryptedPhotos() async {

    final List<EncryptedMediaInfo> encryptedFiles = [];

    try {

      // ----------------------------------------------------------
      // Get saved media folder URIs
      // ----------------------------------------------------------

      final mediaFolders =
          await StorageService.getMediaFolders();

      if (mediaFolders.isEmpty) {

        debugPrint(
          'PhotoRetrievalService: '
          'No protected media folders found.',
        );

        return encryptedFiles;
      }


      // ----------------------------------------------------------
      // Pictures
      // ----------------------------------------------------------

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


      // ----------------------------------------------------------
      // DCIM
      // ----------------------------------------------------------

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


      // ----------------------------------------------------------
      // Remove duplicates
      // ----------------------------------------------------------

      final Map<String, EncryptedMediaInfo>
          uniqueFiles = {};

      for (final file in encryptedFiles) {

        uniqueFiles[file.uri] =
            file;
      }


      final result =
          uniqueFiles.values.toList();


      debugPrint(
        'PhotoRetrievalService: '
        'Found ${result.length} encrypted files.',
      );


      for (final file in result) {

        debugPrint(
          '  ${file.name} '
          '(${file.size} bytes)',
        );
      }


      return result;

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
  /// Android/Kotlin performs the actual SAF traversal.
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


        // --------------------------------------------------------
        // Convert size
        // --------------------------------------------------------

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


        // --------------------------------------------------------
        // Only .dsenc
        // --------------------------------------------------------

        if (!name
            .toLowerCase()
            .endsWith('.dsenc')) {

          continue;
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

  /// Retrieves raw encrypted bytes of ONE `.dsenc` file.
  ///
  /// IMPORTANT:
  /// The returned bytes are still encrypted.
  ///
  /// This loads the complete file into memory.
  /// It is suitable for testing and smaller files.
  ///
  /// For large videos we should later implement streaming.
  static Future<Uint8List?>
      getEncryptedBytes(
    String uri,
  ) async {

    try {

      debugPrint(
        'PhotoRetrievalService: '
        'Reading encrypted file...',
      );

      debugPrint(
        'URI = $uri',
      );


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


      // ==========================================================
      // HASH DEBUGGING
      // ==========================================================

      await _debugEncryptedBytes(
        'ANDROID SAF READ',
        result,
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


  // ============================================================
  // GET ORIGINAL FILE NAME
  // ============================================================

  /// Converts:
  ///
  ///     IMG_001.jpg.dsenc
  ///
  /// into:
  ///
  ///     IMG_001.jpg
  static String getOriginalFileName(
    String encryptedFileName,
  ) {

    if (encryptedFileName
        .toLowerCase()
        .endsWith('.dsenc')) {

      return encryptedFileName.substring(
        0,
        encryptedFileName.length - 5,
      );
    }

    return encryptedFileName;
  }


  // ============================================================
  // GET MIME TYPE
  // ============================================================

  /// Determines the original media MIME type.
  ///
  /// Example:
  ///
  ///     photo.jpg  -> image/jpeg
  ///     photo.png  -> image/png
  ///     video.mp4  -> video/mp4
  static String getMimeType(
    String fileName,
  ) {

    final lower =
        fileName.toLowerCase();


    // ----------------------------------------------------------
    // Images
    // ----------------------------------------------------------

    if (lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg')) {

      return 'image/jpeg';
    }


    if (lower.endsWith('.png')) {

      return 'image/png';
    }


    if (lower.endsWith('.webp')) {

      return 'image/webp';
    }


    if (lower.endsWith('.gif')) {

      return 'image/gif';
    }


    if (lower.endsWith('.bmp')) {

      return 'image/bmp';
    }


    // ----------------------------------------------------------
    // Videos
    // ----------------------------------------------------------

    if (lower.endsWith('.mp4')) {

      return 'video/mp4';
    }


    if (lower.endsWith('.mov')) {

      return 'video/quicktime';
    }


    if (lower.endsWith('.mkv')) {

      return 'video/x-matroska';
    }


    if (lower.endsWith('.avi')) {

      return 'video/x-msvideo';
    }


    // ----------------------------------------------------------
    // Unknown
    // ----------------------------------------------------------

    return 'application/octet-stream';
  }


  // ============================================================
  // UPLOAD ONE ENCRYPTED FILE
  // ============================================================

  /// Uploads one encrypted `.dsenc` file to:
  ///
  ///     POST /files/upload
  ///
  /// The server receives:
  ///
  ///     file
  ///     originalName
  ///     mimeType
  ///
  /// The actual file contents remain encrypted.
  static Future<bool>
      uploadEncryptedFile({
    required EncryptedMediaInfo file,
    required String baseUrl,
    required String accessToken,
  }) async {

    try {

      debugPrint(
        '================================================',
      );

      debugPrint(
        'UPLOAD: Starting',
      );

      debugPrint(
        'UPLOAD: Encrypted file = ${file.name}',
      );

      debugPrint(
        'UPLOAD: Original file = '
        '${getOriginalFileName(file.name)}',
      );

      debugPrint(
        'UPLOAD: Expected size = ${file.size}',
      );


      // ----------------------------------------------------------
      // Read encrypted bytes
      // ----------------------------------------------------------

      final encryptedBytes =
          await getEncryptedBytes(
        file.uri,
      );


      if (encryptedBytes == null ||
          encryptedBytes.isEmpty) {

        debugPrint(
          'UPLOAD: ERROR - '
          'Could not read encrypted bytes.',
        );

        return false;
      }


      debugPrint(
        'UPLOAD: Read '
        '${encryptedBytes.length} encrypted bytes.',
      );


      // ==========================================================
      // HASH DEBUGGING
      // ==========================================================
      //
      // This is intentionally performed AGAIN immediately
      // before constructing the multipart request.
      //
      // Therefore we can prove that the exact bytes being
      // uploaded are unchanged.
      // ==========================================================

      await _debugEncryptedBytes(
        'BEFORE UPLOAD',
        encryptedBytes,
      );


      // ----------------------------------------------------------
      // Original file information
      // ----------------------------------------------------------

      final originalName =
          getOriginalFileName(
        file.name,
      );


      final mimeType =
          getMimeType(
        originalName,
      );


      debugPrint(
        'UPLOAD: MIME type = $mimeType',
      );


      // ----------------------------------------------------------
      // Clean base URL
      // ----------------------------------------------------------

      final cleanBaseUrl =
          baseUrl.endsWith('/')
              ? baseUrl.substring(
                  0,
                  baseUrl.length - 1,
                )
              : baseUrl;


      final uploadUri =
          Uri.parse(
            '$cleanBaseUrl/files/upload',
          );


      debugPrint(
        'UPLOAD: URL = $uploadUri',
      );


      // ----------------------------------------------------------
      // Create multipart request
      // ----------------------------------------------------------

      final request =
          http.MultipartRequest(
        'POST',
        uploadUri,
      );


      // ----------------------------------------------------------
      // Authorization
      // ----------------------------------------------------------

      request.headers[
          'Authorization'] =
          'Bearer $accessToken';


      // ----------------------------------------------------------
      // Metadata
      // ----------------------------------------------------------

      request.fields[
          'originalName'] =
          file.name;

      request.fields[
          'mimeType'] =
          mimeType;


      // ----------------------------------------------------------
      // Encrypted file
      // ----------------------------------------------------------

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          encryptedBytes,
          filename: file.name,
        ),
      );


      debugPrint(
        'UPLOAD: Multipart file size = '
        '${encryptedBytes.length} bytes',
      );

      debugPrint(
        'UPLOAD: Sending request...',
      );


      // ----------------------------------------------------------
      // Send
      // ----------------------------------------------------------

      final streamedResponse =
          await request.send();


      final response =
          await http.Response.fromStream(
        streamedResponse,
      );


      debugPrint(
        'UPLOAD: Status = '
        '${response.statusCode}',
      );


      debugPrint(
        'UPLOAD: Response = '
        '${response.body}',
      );


      // ----------------------------------------------------------
      // Success
      // ----------------------------------------------------------

      if (response.statusCode >= 200 &&
          response.statusCode < 300) {

        debugPrint(
          'UPLOAD: SUCCESS '
          '${file.name}',
        );

        debugPrint(
          '================================================',
        );

        return true;
      }


      // ----------------------------------------------------------
      // Failure
      // ----------------------------------------------------------

      debugPrint(
        'UPLOAD: FAILED '
        '${file.name}',
      );

      debugPrint(
        'Server returned ${response.statusCode}',
      );

      debugPrint(
        '================================================',
      );

      return false;

    } catch (e, stackTrace) {

      debugPrint(
        'UPLOAD ERROR: $e',
      );

      debugPrint(
        'UPLOAD STACK TRACE: $stackTrace',
      );

      return false;
    }
  }


  // ============================================================
  // UPLOAD ALL ENCRYPTED MEDIA
  // ============================================================

  /// Finds all encrypted media and uploads each file.
  ///
  /// Returns the number of successfully uploaded files.
  static Future<int>
      uploadAllEncryptedFiles({
    required String baseUrl,
    required String accessToken,
  }) async {

    try {

      debugPrint(
        '================================================',
      );

      debugPrint(
        'UPLOAD ALL: Searching for encrypted files...',
      );


      final files =
          await getEncryptedPhotos();


      if (files.isEmpty) {

        debugPrint(
          'UPLOAD ALL: No encrypted files found.',
        );

        return 0;
      }


      debugPrint(
        'UPLOAD ALL: '
        '${files.length} encrypted files found.',
      );


      int successCount = 0;


      // ----------------------------------------------------------
      // Upload one at a time
      // ----------------------------------------------------------

      for (
        int i = 0;
        i < files.length;
        i++
      ) {

        final file =
            files[i];


        debugPrint(
          'UPLOAD ALL: '
          'Uploading ${i + 1}/${files.length}',
        );


        final success =
            await uploadEncryptedFile(
          file: file,
          baseUrl: baseUrl,
          accessToken: accessToken,
        );


        if (success) {
          successCount++;
        }
      }


      debugPrint(
        'UPLOAD ALL: Finished.',
      );

      debugPrint(
        'UPLOAD ALL: '
        '$successCount/${files.length} successful.',
      );

      debugPrint(
        '================================================',
      );


      return successCount;

    } catch (e) {

      debugPrint(
        'UPLOAD ALL ERROR: $e',
      );

      return 0;
    }
  }
}