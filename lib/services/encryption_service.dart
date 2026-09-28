// import 'dart:developer';
// import 'dart:typed_data';
// import 'package:flutter/services.dart';

// class EncryptionService {
//   static const MethodChannel _channel =
//       MethodChannel('datashield/encryption');

//   static Future<void> encryptFolder(String uri, Uint8List key) async {
//     try {
//       await _channel.invokeMethod(
//         'encryptFolder',
//         {
//           "uri": uri,
//           "key": key, // Passes unwrapped DEK to Kotlin MainActivity
//         },
//       );
//     } on PlatformException catch (e) {
//       log(
//         "Encryption error: ${e.message}",
//       );
//       rethrow;
//     }
//   }
// }
import 'dart:developer';
import 'dart:typed_data';
import 'package:flutter/services.dart';

import 'media_api_services.dart';

class EncryptionService {
  static const MethodChannel _channel =
      MethodChannel('datashield/encryption');

  static Future<List<Map<String, dynamic>>> encryptFolder(
    String uri,
    Uint8List key,
  ) async {
    try {
      print('ENCRYPTION SERVICE: Calling Kotlin encryptFolder');

      final result = await _channel.invokeMethod(
        'encryptFolder',
        {
          "uri": uri,
          "key": key,
        },
      );

      print(
        'ENCRYPTION SERVICE: Kotlin result = $result',
      );

      if (result == null) {
        print(
          'ENCRYPTION SERVICE: No encrypted files returned',
        );
        return [];
      }

      final encryptedFiles =
          List<Map<String, dynamic>>.from(
        (result as List).map(
          (item) => Map<String, dynamic>.from(item),
        ),
      );

      print(
        'ENCRYPTION SERVICE: '
        '${encryptedFiles.length} files returned',
      );

      // ==========================================================
      // REGISTER EACH NEWLY ENCRYPTED FILE
      // ==========================================================

      for (final file in encryptedFiles) {
        print('----------------------------------------------');
        print(
          'ENCRYPTION SERVICE: Registering '
          '${file['encryptedName']}',
        );

        print(
          'ENCRYPTION SERVICE: Hash = ${file['fileHash']}',
        );

        await MediaApiService.registerFile(
          originalName: file['originalName'] as String,
          encryptedName: file['encryptedName'] as String,
          mimeType: file['mimeType'] as String,
          fileSize: (file['fileSize'] as num).toInt(),
          fileHash: file['fileHash'] as String,
        );

        print(
          'ENCRYPTION SERVICE: Registration completed',
        );
      }

      return encryptedFiles;

    } on PlatformException catch (e) {
      log(
        "Encryption error: ${e.message}",
      );
      rethrow;
    } catch (e) {
      print(
        'ENCRYPTION SERVICE: ERROR = $e',
      );
      rethrow;
    }
  }
}